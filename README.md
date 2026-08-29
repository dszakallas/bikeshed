# bikeshed

This project hosts a devenv module that I import into each of my projects. It helps
define project-scoped MCP servers once and use them across all my agent harnesses (claude, codex, agy, vscode,
copilot-cli, etc.). It also contains some basic git hooks (markdownlint).

Bikeshed also hosts shared home-manager modules for my machines. Despite my efforts, most of these are
still too opinionated for general usage; the `agents` module is probably the most useful for
a general audience. It contains utility functions to set up skills, MCP servers, and system instructions
at the user level.

## Documentation

- [Library Functions](lib/README.md)

## Flake Outputs

This flake exports the following top-level structures:

- `packages`: Custom packages built per system from the `pkgs/` directory.
- `lib`: Reusable [Library Functions](lib/README.md) and utilities.
- `systemModules`: Reusable system-wide modules mapped from `modules/system/`.
- `homeModules`: Reusable Home Manager modules mapped from `modules/home/`.
- `devenvModules`: Reusable modules for `devenv.sh` environments mapped from `modules/devenv/`.

## Fetching private GitHub repositories

> [!CAUTION]
> Never add secrets as pure configuration through [`nix.settings`][darwin-nix-settings]
> or any other managed way, as it will end up in the world reable nix store. The best
> way is to use the [`NIX_CONFIG`][nix-conf-files] environment variable which you put
> in an unmanaged file and source it in your shell profile.

### Pulling flakes

Recent nix has support for path-scoped personal access tokens (PATs) for private repositories.
This allows you to provide a personal access token (PAT) for a specific repository or organization.
This is done by setting the [`access-tokens`][nix-conf-pats] option in your Nix config.

```ini
access-tokens = github.com/<<ORG>>=<<PAT>>
```

where `ORG` is the name of the organization and `PAT` is your personal access token with `repo` scope.
You can add multiple tokens by separating them with spaces. You can also add a fallback token without
a path element.

### `fetchFromGitHubPrivateOrg`

The flake provides a thin wrapper around `fetchFromGitHub` for org scoped PATs for pulling private repositories
during builds.

Idiomatic use is:

1. Turn on the [`configurable-impure-env`][nix-conf-x-cie] experimental feature in your Nix config.
1. Add the following [`impure-env`][nix-conf-ie] to your Nix configuration:

    ```ini
    impure-env = NIX_<<ORG_NAME>>_GITHUB_PRIVATE_USERNAME=<<USERNAME>> NIX_<<ORG_NAME>>_GITHUB_PRIVATE_PASSWORD=<<PAT>>
    ```

    where

    - `ORG_NAME`: is the name of the GitHub organization, suitable for use in env vars, ie. uppercased
      and with dashes replaced by underscores.
    - `USERNAME`: is your GitHub username.
    - `PAT`: is your GitHub fine grained personal access token with `repo` scope for that organization.

    You may repeat this for multiple organizations.

[darwin-nix-settings]: https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-nix.settings
[nix-conf-files]: https://nix.dev/manual/nix/2.28/command-ref/conf-file.html#configuration-file
[nix-conf-pats]: https://nix.dev/manual/nix/2.28/command-ref/conf-file.html#conf-access-tokens
[nix-conf-x-cie]: https://nix.dev/manual/nix/2.28/development/experimental-features#xp-feature-configurable-impure-env
[nix-conf-ie]: https://nix.dev/manual/nix/2.28/command-ref/conf-file#conf-impure-env

## Development

Folder structure:

```text
├── lib                    # library functions
├── modules
│   ├── darwin             # reusable modules for macOS
│   ├── nixos              # reusable modules for nixOS
│   ├── system             # reusable modules for unix-like systems (nixOS, darwin, etc.)
│   ├── devenv             # reusable modules for my projects managed with devenv.sh
│   └── home               # reusable modules for home manager
└── pkgs                   # packages
```
