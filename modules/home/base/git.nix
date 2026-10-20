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
        port
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
                host = mkOption {
                  type = str;
                  default = "github.com";
                  description = "The upstream git host (e.g. github.com, git.kolobok.szakallas.eu)";
                };
                httpScheme = mkOption {
                  type = str;
                  default = "https";
                  description = "The HTTP scheme to use (e.g. https or http)";
                };
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
                  port = mkOption {
                    type = nullOr port;
                    default = null;
                    description = "The SSH port to connect to if non-standard (e.g. 2222)";
                  };
                  hostAlias = mkOption {
                    type = nullOr str;
                    default = null;
                    description = "The SSH host alias/hostname to use (defaults to rule.host if null)";
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
                httpUrl = "${rule.httpScheme}://${rule.host}/${suffix}";
                effectiveHostAlias = if rule.ssh.hostAlias != null then rule.ssh.hostAlias else rule.host;
                sshPortSuffix = lib.optionalString (rule.ssh.port != null) ":${toString rule.ssh.port}";

                # Rewritten SSH destination URL
                targetSshUrl = "ssh://${rule.ssh.user}@${effectiveHostAlias}${sshPortSuffix}/${suffix}";

                # Upstream SSH URLs to match and rewrite
                upstreamUrl = "ssh://${rule.ssh.user}@${rule.host}${sshPortSuffix}/${suffix}";
                upstreamScpUrl = "${rule.ssh.user}@${rule.host}:${suffix}";

                sshBlock =
                  if rule.ssh.enable then
                    let
                      insteadOfKey = if rule.ssh.pushOnly then "pushInsteadOf" else "insteadOf";
                      upstreamRewrite =
                        lib.optionalString (targetSshUrl != upstreamUrl) "  insteadOf = ${upstreamUrl}\n"
                        + lib.optionalString (rule.ssh.port == null && targetSshUrl != upstreamScpUrl) "  insteadOf = ${upstreamScpUrl}\n";
                    in
                    ''
                      [url "${targetSshUrl}"]
                        ${insteadOfKey} = ${httpUrl}
                      ${upstreamRewrite}''
                  else
                    "";
                credBlock =
                  if rule.credential.enable then
                    ''
                      [credential "${httpUrl}"]
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
