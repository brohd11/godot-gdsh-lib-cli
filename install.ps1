# Installs the gdsh CLI: the unpacked release into ~/.gdsh/cli, the `gdsh`
# wrapper (gdsh.cmd + gdsh-cli.ps1) into ~/.local/bin, then registers the Godot binaries it can find.
#   irm https://raw.githubusercontent.com/brohd11/godot-gdsh-cli/main/install.ps1 | iex
#   ./install.ps1 [-From <zip>] [-Dir <bin dir>] [-Force] [-Uninstall]
param([string]$From = '', [string]$Dir = '', [switch]$Force, [switch]$Uninstall)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$url = if ($env:GDSH_CLI_URL) { $env:GDSH_CLI_URL } else { 'https://github.com/brohd11/godot-gdsh-cli/releases/latest/download/gdsh-cli.zip' }
$pkg = 'addons/_lib/gdsh_lib/cli'
# Every wrapper carries this, so reinstall/uninstall only ever touch files this script wrote.
$marker = 'gdsh-cli wrapper'

$gdsh_home = if ($env:GDSH_HOME) { $env:GDSH_HOME } else { Join-Path $HOME '.gdsh' }
$cli = Join-Path $gdsh_home 'cli'
$bin_dir = if ($Dir) { $Dir } else { Join-Path $HOME '.local\bin' }
$wrappers = @{ 'gdsh.cmd' = 'bin/gdsh.cmd'; 'gdsh-cli.ps1' = 'bin/gdsh-cli.ps1' }

function Test-Ours($path) { (Get-Content -LiteralPath $path -Raw) -match [regex]::Escape($marker) }

if ($Uninstall) {
	foreach ($name in $wrappers.Keys) {
		$path = Join-Path $bin_dir $name
		if (-not (Test-Path -LiteralPath $path)) { continue }
		if (Test-Ours $path) { Remove-Item -LiteralPath $path; "Removed $path" }
		else { [Console]::Error.WriteLine("Left ${path}: this script didn't write it.") }
	}
	if (Test-Path -LiteralPath $cli) { Remove-Item -LiteralPath $cli -Recurse -Force; "Removed $cli" }
	"Kept $gdsh_home\executables and your commands."
	exit 0
}

# Refuse before changing anything.
foreach ($name in $wrappers.Keys) {
	$path = Join-Path $bin_dir $name
	if ((Test-Path -LiteralPath $path) -and -not $Force -and -not (Test-Ours $path)) {
		throw "$path exists and wasn't written by this script; rerun with -Force to replace it."
	}
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
	$zip = Join-Path $tmp 'gdsh-cli.zip'
	if ($From) { Copy-Item -LiteralPath $From -Destination $zip }
	else { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing }

	# A relative-path export runs from anywhere, so the package dir is unpacked as-is.
	$unzipped = Join-Path $tmp 'zip'
	[IO.Compression.ZipFile]::ExtractToDirectory($zip, $unzipped)
	$stage = Join-Path $unzipped $pkg
	if (-not (Test-Path -LiteralPath (Join-Path $stage 'boot.gd'))) { throw "not a gdsh-cli release: no $pkg/boot.gd in the zip" }

	New-Item -ItemType Directory -Path $gdsh_home -Force | Out-Null
	if (Test-Path -LiteralPath $cli) { Remove-Item -LiteralPath $cli -Recurse -Force }
	Move-Item -LiteralPath $stage -Destination $cli
	"Installed $cli"
} finally {
	if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
}

New-Item -ItemType Directory -Path $bin_dir -Force | Out-Null
foreach ($name in $wrappers.Keys) {
	$path = Join-Path $bin_dir $name
	Copy-Item -LiteralPath (Join-Path $cli $wrappers[$name]) -Destination $path -Force
	"Installed $path"
}

& (Join-Path $bin_dir 'gdsh.cmd') --register
if ($LASTEXITCODE -ne 0) { 'Register a Godot binary: gdsh --register <path to godot>' }

$user_path = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (($user_path -split ';') | Where-Object { $_.TrimEnd('\') -eq $bin_dir.TrimEnd('\') })) {
	"`n$bin_dir isn't on PATH. Add it:"
	"  [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';$bin_dir', 'User')"
}
