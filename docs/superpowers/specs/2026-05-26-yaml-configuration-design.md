# YAML Configuration Storage Design

## Goal

Replace JSON on-disk configuration with YAML for application-managed config files. No backward compatibility with `.json` files.

## Scope

| File | Location |
|------|----------|
| `config.yaml` | `{configurationDirectory}/` |
| `gestures.yaml` | `{configurationDirectory}/` |
| `config_standalone.yaml` | `~/Library/Application Support/GestureFlow/` |

Out of scope: settings window frame persistence, JSON→YAML migration, dual-format reads.

## Approach

- Add **Yams** to `GestureFlowCore`.
- Shared `YAMLConfigurationCoder` for encode/decode of existing `Codable` models (camelCase keys unchanged).
- Update `ConfigurationStore`, `GestureConfigurationStore`, `StandaloneConfigurationStore`, `ConfigurationDirectoryResolver`, and `ConfigurationDirectoryRelocator`.
- Corrupt-file backup pattern: `{filename}.corrupt-{timestamp}` (e.g. `config.yaml.corrupt-...`).

## Non-Goals

- Human-editing optimizations (comments, field ordering).
- Reading legacy `.json` files.
