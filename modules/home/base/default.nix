{ self, packages, ... }@ctx:
{
  config,
  hostPlatform,
  lib,
  options,
  pkgs,
  system,
  ...
}:
let
  inherit (lib)
    flatten
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionals
    types
    ;
  unmanagedFile =
    f:
    ctx.lib.textRegion {
      name = moduleName;
      content = ''
        # Unmanaged local overrides
        [[ -s "$HOME/.local/share/${f}" ]] && source "$HOME/.local/share/${f}"
      '';
    };
  files = with pkgs; [
    age
    bat
    findutils
    fswatch
    gawk
    gnused
    gnumake
    ripgrep
    rsync
    sops
    tree
    zstd
  ];
  adm = with pkgs; [
    btop
    dig
    htop
    ncdu
    nmap
    tmux
  ];
  nix = with pkgs; [
    devenv
  ];
  dev = with pkgs; [
    delta
    jq
    yq-go
  ];
  moduleName = "davids-dotfiles-common/home/base";
in
{
  imports = [
    (import ./fzf.nix ctx)
    (import ./k8s.nix ctx)
    (import ./go.nix ctx)
    (import ./python.nix ctx)
  ]
  ++ (optionals hostPlatform.isDarwin [ (import ./darwin.nix ctx) ]);
  options =
    let
      inherit (types)
        mergeTypes
        lines
        attrsOf
        submodule
        bool
        str
        listOf
        either
        path
        nullOr
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
        authentication = {
          rules = mkOption {
            type = listOf (submodule {
              options = {
                pathPrefix = mkOption {
                  type = str;
                  default = "";
                  description = "The repository path prefix to match (e.g. org name, or empty for all)";
                };
                credential = {
                  enable = mkOption {
                    type = bool;
                    default = false;
                    description = "Whether to configure git credentials for this prefix";
                  };
                  username = mkOption {
                    type = str;
                    default = "";
                    description = "The credential username";
                  };
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
  config = {
    bikeshed.git.excludesLines = mkIf config.bikeshed.git.enable (
      ctx.lib.textRegion {
        name = moduleName;
        content = builtins.readFile ./gitignore;
      }
    );
    bikeshed.git.configLines = mkIf config.bikeshed.git.enable (
      let
        authConfig =
          let
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
                        username = ${rule.credential.username}
                    ''
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
          + (lib.optionalString hostPlatform.isDarwin ''

            [credential]
            	helper = osxkeychain
          '')
          + (lib.optionalString (authConfig != "") ''

            # Generated git authentication rules
            ${authConfig}
          '')
          + (lib.optionalString (includesConfig != "") ''

            # Included git config files
            ${includesConfig}
          '');
      }
    );
    home = {
      packages = flatten [
        adm
        files
        dev
        nix
      ];
      file.".gitconfig" = mkIf config.bikeshed.git.enable {
        text = config.bikeshed.git.configLines;
      };
      file.".gitexcludes" = mkIf config.bikeshed.git.enable {
        text = config.bikeshed.git.excludesLines;
      };
      file.".vimrc".text = ctx.lib.textRegion {
        name = moduleName;
        comment-char = ''"'';
        content = builtins.readFile ./vimrc;
      };
      # in some shell scripts, alias doesn't work, so we use a wrapper script
      file.".davids/bin/docker" = {
        text = ''
          #!/bin/sh
          exec podman "$@"
        '';
        executable = true;
      };
      sessionVariables = {
        EDITOR = "vim";
        LANG = "en_US.UTF-8";
      };
      shellAliases = mkMerge [
        {
          la = "ls -la";
          v = "vim";
          docker = "podman";
        }
        (mkIf config.bikeshed.git.enable {
          g = "git";
        })
      ];
      file.".ssh/bikeshed.known_hosts" = mkIf config.bikeshed.ssh.enable {
        text = config.bikeshed.ssh.knownHostsLines;
      };
    };
    programs = {
      vim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [
          vim-airline
          vim-fugitive
          vim-surround
          nerdcommenter
          ctrlp-vim
          syntastic
          srcery-vim
          editorconfig-vim
          tagbar
        ];
        settings = {
          ignorecase = true;
        };
      };

      direnv = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      bash = {
        enable = true;
        bashrcExtra = unmanagedFile "bashrc";
        profileExtra = ''
          export PATH="$HOME/.davids/bin:$PATH"
          # Unmanaged executables
          export PATH="$HOME/.local/bin:$PATH"
        ''
        + unmanagedFile "env";
      };

      zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        history = {
          path = "$HOME/.histfile";
        };

        initContent = unmanagedFile "zshrc";
        envExtra = ''
          export PATH="$HOME/.davids/bin:$PATH"
          # Unmanaged executables
          export PATH="$HOME/.local/bin:$PATH"
        ''
        + unmanagedFile "env";

        oh-my-zsh = {
          enable = true;
          plugins = [
            "direnv"
          ]
          ++ optionals config.bikeshed.git.enable [ "git" ];
          theme = "fino-time";
        };
      };
    };
  };
}
