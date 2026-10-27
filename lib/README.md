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

See [agents/README.md](agents/README.md) for the agent library, including memory, skills, and MCP configuration.
