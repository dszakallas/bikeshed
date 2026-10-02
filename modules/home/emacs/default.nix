ctx@{ packages, ... }:
{
  pkgs,
  config,
  lib,
  system,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionals
    types
    ;
in
{
  options = {
    bikeshed.emacs = {
      enable = mkEnableOption "Emacs configuration";
      daemon = mkOption {
        default = { };
        type = types.submodule {
          options = {
            enable = mkEnableOption "Enable Emacs daemon";
          };
        };
      };
      package = mkOption {
        default = packages.${system}.davids-emacs;
        type = types.package;
        description = "Emacs package";
      };
      spacemacs = mkOption {
        default = { };
        type = types.submodule {
          options = {
            enable = mkEnableOption "Enable Spacemacs management";
            type = mkOption {
              type = types.enum [
                "package"
                "local"
              ];
              default = "package";
              description = "Spacemacs source type (package or impure local dir)";
            };
            package = mkOption {
              default = packages.${system}.spacemacs;
              type = types.package;
              description = "Spacemacs package";
            };
            local = mkOption {
              type = types.str;
              description = "Spacemacs local path (used if type is 'local')";
            };
            config = mkOption {
              default = { };
              type = types.submodule {
                options = {
                  enable = mkEnableOption "Enable Spacemacs configuration management";
                  path = mkOption {
                    type = types.path;
                    description = "Path to Spacemacs configuration";
                  };
                };
              };
            };
          };
        };
      };
      doomUnstraightened = mkOption {
        default = { };
        type = types.submodule (
          submoduleArgs:
          let
            subConfig = submoduleArgs.config;
          in
          {
            options = {
              enable = mkEnableOption "Doom Emacs via nix-doom-emacs-unstraightened";

              doomDir = mkOption {
                type = types.pathInStore;
                description = "The DOOMDIR to build from and bundle.";
              };

              doomLocalDir = mkOption {
                type = types.path;
                default = "${config.xdg.dataHome}/nix-doom";
                defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/nix-doom"'';
                description = "DOOMLOCALDIR.";
              };

              emacs = mkOption {
                type = types.package;
                default = config.bikeshed.emacs.package;
                defaultText = lib.literalExpression "config.bikeshed.emacs.package";
                description = "The Emacs package to wrap.";
              };

              profileName = mkOption {
                type = types.str;
                default = "nix";
                description = "Doom profile. Set to the empty string to disable.";
              };

              experimentalFetchTree = mkOption {
                type = types.bool;
                default = false;
                description = "Fetch packages using fetchTree instead of fetchGit.";
              };

              extraPackages = mkOption {
                default = self: [ ];
                type = lib.hm.types.selectorFunction or (types.functionTo (types.listOf types.package));
                defaultText = lib.literalExpression "epkgs: [ ]";
                description = "Extra Emacs packages from nixpkgs available to Doom Emacs.";
              };

              extraBinPackages = mkOption {
                default = with pkgs; [
                  ripgrep
                  git
                  fd
                ];
                type = types.listOf types.package;
                defaultText = lib.literalExpression "with pkgs; [ ripgrep git fd ]";
                description = "Extra packages to add to Doom's $PATH.";
              };

              tangleArgs = mkOption {
                default = null;
                type = types.nullOr types.str;
                defaultText = lib.literalExpression null;
                description = "When set, run `doom +org tangle $tangleArgs` in doomDir.";
              };

              emacsPackageOverrides = mkOption {
                default = eself: esuper: { };
                type = types.functionTo (types.functionTo (types.lazyAttrsOf types.package));
                description = "Function passed to (emacsPackagesFor emacs).overrideScope.";
              };

              provideEmacs = mkOption {
                type = types.bool;
                default = true;
                description = "If enabled (the default), provide emacs (and emacsclient, etc).";
              };

              finalEmacsPackage = mkOption {
                type = types.package;
                readOnly = true;
                description = "The final Emacs-compatible package (providing an emacs binary).";
              };

              finalDoomPackage = mkOption {
                type = types.package;
                readOnly = true;
                description = "The final Doom Emacs package (providing a doom-emacs binary).";
              };
            };

            config = mkIf subConfig.enable (
              let
                doomPackages = ctx.nix-doom-emacs-unstraightened.lib.doomFromPackages pkgs {
                  inherit (subConfig)
                    doomDir
                    doomLocalDir
                    emacs
                    profileName
                    experimentalFetchTree
                    extraPackages
                    extraBinPackages
                    tangleArgs
                    emacsPackageOverrides
                    ;
                };
              in
              {
                finalDoomPackage = doomPackages.doomEmacs;
                finalEmacsPackage = doomPackages.emacsWithDoom;
              }
            );
          }
        );
        description = "Configuration for Doom Emacs via nix-doom-emacs-unstraightened";
      };
    };
  };
  config = mkIf config.bikeshed.emacs.enable (
    let
      doomCfg = config.bikeshed.emacs.doomUnstraightened;
      isDoom = doomCfg.enable;
      effectiveEmacsPackage =
        if isDoom && doomCfg.provideEmacs then
          doomCfg.finalEmacsPackage
        else
          config.bikeshed.emacs.package;

      pkg = config.bikeshed.emacs.spacemacs.package;
      spacemacs-start-directory =
        if config.bikeshed.emacs.spacemacs.type == "package" then
          "${pkg.out}/share/spacemacs"
        else
          config.bikeshed.emacs.spacemacs.local;
      loadSpacemacsInit = f: ''
        (setq spacemacs-start-directory "${spacemacs-start-directory}/")
        (add-to-list 'load-path spacemacs-start-directory)
        (load "${f}" nil t)
      '';
      moduleName = "bikeshed/home/emacs";
    in
    lib.mkMerge [
      {
        launchd.agents."eu.szakallas.emacs" = mkIf pkgs.stdenv.hostPlatform.isDarwin {
          enable = config.bikeshed.emacs.daemon.enable;
          config = {
            ProgramArguments = [
              "${effectiveEmacsPackage}/Applications/Emacs.app/Contents/MacOS/Emacs"
              "--fg-daemon"
            ];
            KeepAlive = true;
          };
        };

        home.packages =
          with pkgs;
          [
            effectiveEmacsPackage
            # lsp dependencies
            nodejs
            # vterm build dependencies
            cmakeMinimal
            glibtool
          ]
          ++ (optionals
            (config.bikeshed.emacs.spacemacs.enable && config.bikeshed.emacs.spacemacs.type == "package")
            [
              config.bikeshed.emacs.spacemacs.package
            ]
          );

        bikeshed.git.excludesLines = ctx.lib.textRegion {
          name = moduleName;
          content = builtins.readFile ./gitignore;
        };
        bikeshed.git.configLines = ctx.lib.textRegion {
          name = moduleName;
          content = ''
            [magithub]
              online = false
            [magithub "status"]
              includeStatusHeader = false
              includePullRequestsSection = false
              includeIssuesSection = false
          '';
        };
        home.file.".bikeshed/bin/ect" = {
          text = ''
            #!/bin/sh
            exec ${effectiveEmacsPackage}/bin/emacsclient --tty "$@"
          '';
          executable = true;
        };
        home.file.".bikeshed/bin/ecw" = {
          text = ''
            #!/bin/sh
            exec ${effectiveEmacsPackage}/bin/emacsclient --reuse-frame -a "" "$@"
          '';
          executable = true;
        };
        home.file.".bikeshed/bin/ec" = {
          text = ''
            #!/bin/sh
            exec ${effectiveEmacsPackage}/bin/emacsclient "$@"
          '';
          executable = true;
        };
        home.file.".spacemacs.d" =
          mkIf (config.bikeshed.emacs.spacemacs.enable && config.bikeshed.emacs.spacemacs.config.enable)
            {
              source = config.bikeshed.emacs.spacemacs.config.path;
            };
        home.file.".emacs.d/init.el" = mkIf config.bikeshed.emacs.spacemacs.enable {
          text = loadSpacemacsInit "init";
        };
        home.file.".emacs.d/early-init.el" = mkIf config.bikeshed.emacs.spacemacs.enable {
          text = loadSpacemacsInit "early-init";
        };
        home.file.".emacs.d/dump-init.el" = mkIf config.bikeshed.emacs.spacemacs.enable {
          text = loadSpacemacsInit "dump-init";
        };
        programs.zsh = {
          shellAliases = {
            e = "ect";
          };
          initContent = ctx.lib.textRegion {
            name = moduleName;
            content = ''
              if [ -n "$INSIDE_EMACS" ]; then
                export EDITOR=ec
              fi
            '';
          };
        };
        programs.bash = {
          bashrcExtra = ctx.lib.textRegion {
            name = moduleName;
            content = ''
              if [ -n "$INSIDE_EMACS" ]; then
                export EDITOR=ec
              fi
            '';
          };
        };
      }
    ]
  );
}
