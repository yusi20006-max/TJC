# TJC v2.1 Plugin Runtime

TJC plugins are local, opt-in extensions controlled by a manifest and the central Policy Engine.

## Layout

```text
~/.config/tjc/plugins/<name>/
  plugin.yml
  entrypoint.sh
```

## Manifest

```yaml
schema_version: 1
name: example
entrypoint: entrypoint.sh
capabilities:
  - plugin.execute
```

Supported capabilities:

- `plugin.execute`
- `filesystem.read`
- `filesystem.write`
- `network.read`
- `provider.read`
- `provider.execute`

## Security Boundary

Plugins are never enabled implicitly. `tjc plugin run` requires `plugin.execute` and then requires Policy authorization for every capability declared by the plugin.

The default policy denies plugin execution and filesystem writes. A plugin cannot silently expand its authority by changing its own manifest.

Plugin names are restricted to letters, numbers, `_`, and `-`. Entry points cannot be absolute paths or contain traversal components. Symlinks are rejected during validation and local installation so an installed plugin cannot redirect execution outside its plugin directory.

The manifest is parsed as YAML and never evaluated as shell source. User arguments are passed as positional arguments rather than concatenated into a command string.

## Commands

```sh
tjc plugin list
tjc plugin show <name>
tjc plugin install <directory>
tjc plugin run <name> [args...]
```

Plugins execute with the operating-system permissions of the TJC process. The Policy Engine is an authorization boundary, not an OS sandbox; production plugins should therefore be reviewed before installation.
