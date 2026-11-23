# gdsh CLI

Run [gdsh](https://github.com/brohd11/godot-gdsh) commands from a terminal, headless, in any Godot project, with no gdsh in it:

```sh
gdsh 'ls res://addons'
gdsh 'namespace build'
gdsh -f script.gdsh
```

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/brohd11/godot-gdsh-cli/main/install.sh | sh
```

```powershell
irm https://raw.githubusercontent.com/brohd11/godot-gdsh-cli/main/install.ps1 | iex
```

The installer unpacks the release into `~/.gdsh/cli/` and the `gdsh` wrapper in `~/.local/bin`. It then registers the Godot binaries it finds in `~/.gdsh/executables` (from `$GODOT`, `godot` on PATH and `/Applications/Godot*.app`). To add others, run `gdsh --register <path to godot>`. Rerun the installer to update it. Options: `--from <zip>` installs a local release, and `--uninstall` removes the CLI but keeps your registry and commands. `$GDSH_HOME` replaces `~/.gdsh`.

## How it runs

The wrapper finds the enclosing `project.godot`. It picks the registered Godot matching the project's `config/features` version, preferring mono when the project uses C#; `$GODOT` overrides this. It then runs `boot.gd` headless.

The release is a relative-path export, so it runs from `~/.gdsh/cli` without being copied into the project. The CLI uses the project's own gdsh when it has one, and otherwise the copy bundled in `vendor/`. It offers:

- the builtins
- gdsh-lib-utils
- every enabled plugin's `cmd/`
- the `~/.gdsh` and `res://.gdsh` command roots

Commands that need the editor still load, and fail with their own error when run.
