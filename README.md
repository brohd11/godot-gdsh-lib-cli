# gdsh CLI payload

The GDScript half of the [gdsh CLI](https://github.com/brohd11/gdsh): `boot.gd`, `src/run.gd` and the
[gdsh](https://github.com/brohd11/godot-gdsh) copy bundled beside them. Install the CLI from its repo; it
embeds this package's release and unpacks it to `~/.gdsh/cli` (`$GDSH_HOME/cli`) on first run.

```sh
curl -fsSL https://raw.githubusercontent.com/brohd11/gdsh/main/install.sh | sh
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
- every enabled plugin's `cmd/`
- the `~/.gdsh` and `res://.gdsh` command roots

Commands that need the editor still load, and fail with their own error when run.

## Releasing

Tag a release here (the standard gdpackage `release.yml` publishes `gdsh-cli.zip`), then vendor it into the Go
repo with `scripts/fetch_payload.sh` and release that.
