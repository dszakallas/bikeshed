{ self, packages, ... }@ctx:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  moduleName = "bikeshed/home/base";
in
{
  options =
    let
      inherit (types)
        bool
        either
        lines
        listOf
        nullOr
        path
        str
        submodule
        ;
    in
    {
      bikeshed.git = {
        enable = mkEnableOption "Git goodies";
        excludesLines = mkOption {
          type = lines;
          description = "Lines to add to the user-wide git excludes file";
          default = "";
        };
        configLines = mkOption {
          type = lines;
          description = "Lines to add to the user-wide git config file";
          default = "";
        };
        includes = mkOption {
          type = listOf (submodule {
            options = {
              includeIf = mkOption {
                type = nullOr str;
                default = null;
                description = "Condition for conditional include (includeIf). If null, a standard include is generated.";
              };
              path = mkOption {
                type = either path str;
                description = "The path to the git config file to include. Can be a Nix store path or a string representing a path.";
              };
            };
          });
          default = [ ];
          description = "External git config files to include";
        };
        credentialHelper = mkOption {
          type = nullOr str;
          default = null;
          description = "The top-level git credential helper (falls back for any prefix that doesn't set its own). If null, none is configured.";
        };
        authentication = {
          rules = mkOption {
            type = listOf (submodule {
              options = {
                pathPrefix = mkOption {
                  type = str;
                  default = "";
                  description = "The repository path prefix to match (e.g. org name, or empty for all)";
                };
                credential = mkOption {
                  type = ctx.lib.git.credentialType;
                  default = { };
                  description = "Credential configuration for this prefix.";
                };
                ssh = {
                  enable = mkOption {
                    type = bool;
                    default = false;
                    description = "Whether to configure SSH rewrite rules for this prefix";
                  };
                  user = mkOption {
                    type = str;
                    default = "git";
                    description = "The SSH username to use";
                  };
                  hostAlias = mkOption {
                    type = str;
                    default = "github.com";
                    description = "The SSH host alias/hostname to use";
                  };
                  pushOnly = mkOption {
                    type = bool;
                    default = false;
                    description = "Whether to only rewrite urls when pushing";
                  };
                };
              };
            });
            default = [ ];
            description = "Rules to generate Git authentication configuration";
          };
        };
      };
    };

  config = mkIf config.bikeshed.git.enable {
    bikeshed.git.excludesLines = ctx.lib.textRegion {
      name = moduleName;
      content = builtins.readFile ./gitignore;
    };

    bikeshed.git.configLines =
      let
        authConfig =
          let
            # git config truncates unquoted values at the first unescaped
            # ';' or '#' (treated as an inline comment), so any value that
            # might contain shell syntax (e.g. a credential.helper script)
            # must be quoted and have its backslashes/quotes escaped.
            escapeGitConfigValue = v: ''"'' + builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] v + ''"'';
            genRule =
              rule:
              let
                suffix = rule.pathPrefix;
                sshBlock =
                  if rule.ssh.enable then
                    let
                      insteadOfKey = if rule.ssh.pushOnly then "pushInsteadOf" else "insteadOf";
                      gitSshUrl = "git@github.com:${suffix}";
                    in
                    ''
                      [url "ssh://${rule.ssh.user}@${rule.ssh.hostAlias}/${suffix}"]
                        insteadOf = ${gitSshUrl}
                        ${insteadOfKey} = https://github.com/${suffix}
                    ''
                  else
                    "";
                credBlock =
                  if rule.credential.enable then
                    ''
                      [credential "https://github.com/${suffix}"]
                    ''
                    + lib.optionalString (
                      rule.credential.username != null
                    ) "  username = ${escapeGitConfigValue rule.credential.username}\n"
                    + lib.optionalString (
                      rule.credential.helper != null
                    ) "  helper = ${escapeGitConfigValue rule.credential.helper}\n"
                  else
                    "";
              in
              sshBlock + credBlock;
          in
          builtins.concatStringsSep "" (map genRule config.bikeshed.git.authentication.rules);

        includesConfig =
          let
            genInclude =
              inc:
              if inc.includeIf != null && inc.includeIf != "" then
                ''
                  [includeIf "${inc.includeIf}"]
                    path = ${toString inc.path}
                ''
              else
                ''
                  [include]
                    path = ${toString inc.path}
                '';
          in
          builtins.concatStringsSep "" (map genInclude config.bikeshed.git.includes);
      in
      ctx.lib.textRegion {
        name = moduleName;
        content =
          builtins.readFile ./gitconfig
          + (lib.optionalString (config.bikeshed.git.credentialHelper != null) ''

            [credential]
              helper = ${config.bikeshed.git.credentialHelper}
          '')
          + (lib.optionalString (authConfig != "") ''

            # Generated git authentication rules
            ${authConfig}
          '')
          + (lib.optionalString (includesConfig != "") ''

            # Included git config files
            ${includesConfig}
          '');
      };

    home = {
      packages = [ pkgs.git ];
      file.".gitconfig" = {
        text = config.bikeshed.git.configLines;
      };
      file.".gitexcludes" = {
        text = config.bikeshed.git.excludesLines;
      };
      shellAliases = {
        g = "git";
      };
    };

    programs.zsh.oh-my-zsh.plugins = [ "git" ];
  };
}
