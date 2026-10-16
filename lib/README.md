# bikeshed/lib

This directory contains reusable Nix library functions used throughout the dotfiles.

## Imports (`imports.nix`)

- `mapRec { node, mapf }`: Walks a directory of `.nix` files recursively and maps each
  leaf with a function. A leaf is either a `.nix` file or a directory containing
  `default.nix`.
- `importRec node`: Imports a directory of `.nix` files recursively as an attribute set.
- `importRec1 node a`: Imports a directory of `.nix` files recursively, passing the
  argument `a` to each imported file.
- `callPackageWithRec pkgs node`: Like `lib.callPackageWith` but for an entire directory
  of packages. The packages are imported with their file basename as the attribute name
  and returned as an attribute set.

## Text (`text.nix`)

- `textRegion { name, content, comment-char ? "#" }`: Annotates a region of multi-line
  text with begin/end markers. Useful for identifying the origin of blocks in generated
  configuration files.

## Git (`git.nix`)

- `git.credentialType`: Shared `home-manager` submodule type for configuring a git credential
  block (`enable`, `username`, `helper`), reused by `bikeshed.git.authentication.rules.*.credential`
  and by userPresets that expose their own configurable credential block.
- `git.mkEnvCredentialHelper prefix`: Returns a git credential helper script that reads the
  username/password from the environment variables `"${prefix}USERNAME"` and `"${prefix}PASSWORD"`.

## Agents (`agents/`)

For a comprehensive guide to the MCP server configuration schema, see [agents/README.md](agents/README.md).

- `agents.mcpServerType`: Submodule option type for an individual generic MCP server definition (`type`, `command`,
  `args`, `env`, `serverUrl`, `headers`).
- `agents.mcpServersType`: Attribute set option type (`attrsOf mcpServerType`) for declaring generic MCP servers.
- `agents.mcpServersForAgent agent value`: Transforms a generic `mcpServers`
  attribute set mapping into configurations specifically formatted for a particular AI
  coding agent (e.g., `vscode`, `claude`, `gemini`, `copilot`, `opencode`, `antigravity`). Resolves mutually
  exclusive properties (like `command`, `serverUrl`, `headers`) and outputs them
  according to what each agent accepts. See [agents/README.md](agents/README.md) for full schema details.
- `agents.mkSkill pkgs { name, version, src, sourceRoot ? null, include ? null, ... }`: Creates a Nix
  derivation containing AI coding agent skills. It searches the source path for directories containing a `SKILL.md`
  file, optionally filtering them via `include` and `exclude` lists, and copies them to the output path.
  - `pkgs`: Package set providing `stdenvNoCC`.
  - `name`: Derivation name (`pname`).
  - `version`: Derivation version.
  - `src`: Source directory containing skills.
  - `sourceRoot`: Optional subdirectory within `src` to search (formerly `subDir`). Defaults to `"skills"` if it
    exists, otherwise the root of `src`.
  - `include`: Optional list of skill names to include. If `null` or omitted, all discovered skills are included.
  - `exclude`: Optional list of skill names to exclude.
  - `preserveSourceRoot`: Optional boolean (default `false`). When `true`, preserves all files in the source root
    (plugin style) rather than copying only the discovered skill folders.
- `agents.assembleSkills pkgs entries`: Assembles skills from an attribute set or list of skill paths into a single
  derivation containing all discovered skills (symlinked by skill name).
- `agents.assembleSkillsText`: The raw bash script text executed by `agents.assembleSkills`.
- `agents.harnesses`: Attribute set of supported harness specifications.
- `agents.popularHarnesses`: List of popular agent harness identifiers that bikeshed can configure (`"antigravity"`,
  `"claude"`, `"codex"`, `"copilot"`, `"gemini"`, `"opencode"`, `"pi"`, `"vscode"`).
- `agents.allHarnesses`: List of all agent harness identifiers bikeshed can configure. Currently identical to
  `popularHarnesses`.
