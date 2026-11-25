# gdsh CLI payload

The GDScript half of the [gdsh CLI](https://github.com/brohd11/godot-gdsh-cli): `boot.gd`, `src/run.gd` and the
[gdsh](https://github.com/brohd11/godot-gdsh) copy bundled beside them. Install the CLI from its repo; it
embeds this package's release and unpacks it to `~/.gdsh/cli` (`$GDSH_HOME/cli`) on first run.

```sh
curl -fsSL https://raw.githubusercontent.com/brohd11/godot-gdsh-cli/main/install.sh | sh
```

## How it runs

The `gdsh` binary finds the enclosing `project.godot` and the registered Godot for it, then runs:

```sh
godot --headless --path <project> --script ~/.gdsh/cli/boot.gd -- -c '<line>' | -f <file.gdsh>
```

The release is a relative-path export, so it runs from `~/.gdsh/cli` without being copied into the project.
It uses the project's own gdsh when it has one, and otherwise the copy bundled in `vendor/`. It offers:

- the builtins
- gdsh-lib-utils
- gdsh-lib-test (`test <package>/...` runs a package's suites)
- gdsh-lib-data (`data to_json|to_yaml|to_bin` converts data files)
- `settings` from gdsh-lib-editor (`psetting`, `mainscene`; `esetting` needs the editor)
- every enabled plugin's `cmd/`
- the `~/.gdsh` and `res://.gdsh` command roots

Commands that need the editor still load, and fail with their own error when run.

Before the line runs, `~/.gdrc` and then `res://.gdrc` are sourced, as in Editor Console, so their functions and
aliases are available. Their output and errors show ahead of the command's. `$GDSH_HOST` is `cli` (Editor
Console sets `editor_console`, MCP requests `mcp`), so an rc can skip editor-only lines: `[ "$GDSH_HOST" == "editor_console" ] && ...`. Set
`GDSH_NORC=1` to skip the rc files.

## Releasing

Tag a release here (the standard gdpackage `release.yml` publishes `gdsh-cli.zip`), then vendor it into the Go
repo with `scripts/fetch_payload.sh` and release that.
