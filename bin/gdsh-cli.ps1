# gdsh-cli wrapper: runs gdsh headless in the enclosing Godot project, with the CLI installed in
# ~/.gdsh/cli by godot-gdsh-cli's install.ps1. Godot binaries are registered in ~/.gdsh/executables
# (gdsh --register); $env:GODOT overrides the lookup.
$gdsh_home = if ($env:GDSH_HOME) { $env:GDSH_HOME } else { Join-Path $HOME '.gdsh' }
$cli = Join-Path $gdsh_home 'cli'
$registry = Join-Path $gdsh_home 'executables'
$usage = "Usage: gdsh '<line>' | gdsh -f <file.gdsh> | gdsh --register [<godot>...] | gdsh --version | gdsh --help"
$help = @'
Usage: gdsh '<line>'                 run a gdsh line in the enclosing Godot project
       gdsh -f <file.gdsh>           run a gdsh script (starts with #!gdsh)
       gdsh --register [<godot>...]  record Godot binaries in ~/.gdsh/executables
       gdsh --version | --help

The line is gdsh syntax, as in the Editor Console, not PowerShell: quote it so your shell
passes it whole. Blocks use braces:
  gdsh 'for f in $(ls res://) { echo "file: $f" }'
Output is plain text, so it pipes into your shell's tools:
  gdsh 'ls res://' | Select-String '/$'
'@

if ($args.Count -gt 0 -and $args[0] -in @('-h', '--help')) { $help; exit 0 }
if ($args.Count -gt 0 -and $args[0] -eq '--version') {
	$cfg = Join-Path $cli 'package.cfg'
	if (-not (Test-Path -LiteralPath $cfg)) { [Console]::Error.WriteLine("gdsh: the CLI isn't installed in $cli"); exit 1 }
	$found = Select-String -LiteralPath $cfg -Pattern '^version="(.*)"' | Select-Object -First 1
	"gdsh-cli $(if ($found) { $found.Matches[0].Groups[1].Value })"
	exit 0
}

# Drops Godot's banner and the blank line after it.
function Remove-Banner {
	begin { $state = 0 }
	process {
		if ($state -eq 0) { $state = 1; if ($_ -like 'Godot Engine v*') { return } else { $state = 2 } }
		if ($state -eq 1) { $state = 2; if ($_ -eq '') { return } }
		$_
	}
}

if ($args.Count -gt 0 -and $args[0] -eq '--register') {
	$bins = @($args | Select-Object -Skip 1)
	if ($bins.Count -eq 0) {
		if ($env:GODOT) { $bins += $env:GODOT }
		$found = Get-Command godot -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($found) { $bins += $found.Source }
	}
	if ($bins.Count -eq 0) { [Console]::Error.WriteLine("gdsh: no Godot found; run: gdsh --register <path to godot>"); exit 1 }
	# Godot loads a project.godot in its cwd (autoloads, extensions), so register from an empty dir.
	$empty = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName()))
	$status = 0
	Push-Location $empty
	try {
		foreach ($bin in $bins) {
			& $bin --headless --script (Join-Path $cli 'register.gd') | Remove-Banner
			if ($LASTEXITCODE -ne 0) { $status = 1 }
		}
	} finally {
		Pop-Location
		Remove-Item -LiteralPath $empty -Recurse -Force
	}
	exit $status
}
if ($args.Count -eq 0) { [Console]::Error.WriteLine($usage); exit 1 }
$boot = Join-Path $cli 'boot.gd'
if (-not (Test-Path -LiteralPath $boot)) { [Console]::Error.WriteLine("gdsh: the CLI isn't installed in $cli"); exit 1 }

$proj = (Get-Location).ProviderPath
while ($proj -and -not (Test-Path -LiteralPath (Join-Path $proj 'project.godot'))) {
	$proj = Split-Path -Parent $proj
}
if (-not $proj) { [Console]::Error.WriteLine("gdsh: no project.godot above $(Get-Location)"); exit 1 }

$godot = $env:GODOT
if (-not $godot) {
	$features = Select-String -LiteralPath (Join-Path $proj 'project.godot') -Pattern '^config/features=' |
		Select-Object -First 1
	$ver = ''; $want = ''
	if ($features) {
		if ($features.Line -match 'PackedStringArray\("([0-9.]+)"') { $ver = $Matches[1] }
		if ($features.Line -match '"C#"') { $want = '-mono' }
	}
	$exact = ''; $other = ''
	if ($ver -and (Test-Path -LiteralPath $registry)) {
		foreach ($line in Get-Content -LiteralPath $registry) {
			$key, $path = $line -split ': ', 2
			if (-not $path -or -not $key.StartsWith("godot-$ver.")) { continue }
			$mono = if ($key.EndsWith('-mono')) { '-mono' } else { '' }
			if ($mono -eq $want) { $exact = $path } else { $other = $path }
		}
	}
	$godot = if ($exact) { $exact } else { $other }
	if (-not $godot) {
		$shown = if ($ver) { $ver } else { '(unknown version)' }
		[Console]::Error.WriteLine("gdsh: no Godot $shown registered in $registry")
		[Console]::Error.WriteLine("  register one: gdsh --register <path to godot>")
		exit 1
	}
}

if ($args[0] -eq '-f') {
	if ($args.Count -lt 2 -or -not (Test-Path -LiteralPath $args[1] -PathType Leaf)) {
		[Console]::Error.WriteLine("gdsh: no such file: $($args[1])"); exit 1
	}
	$run_args = @('-f', (Resolve-Path -LiteralPath $args[1]).ProviderPath)
} else {
	$run_args = @('-c', ($args -join ' '))
}

& $godot --headless --path $proj --script $boot -- @run_args | Remove-Banner
exit $LASTEXITCODE
