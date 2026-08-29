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
    };
  };
  config = mkIf config.bikeshed.emacs.enable (
    let
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
    {
      launchd.agents."eu.szakallas.emacs" = mkIf pkgs.stdenv.hostPlatform.isDarwin {
        enable = config.bikeshed.emacs.daemon.enable;
        config = {
          ProgramArguments = [
            "${config.bikeshed.emacs.package}/Applications/Emacs.app/Contents/MacOS/Emacs"
            "--fg-daemon"
          ];
          KeepAlive = true;
        };
      };

      home.packages =
        with pkgs;
        [
          config.bikeshed.emacs.package
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
          exec ${config.bikeshed.emacs.package}/bin/emacsclient --tty "$@"
        '';
        executable = true;
      };
      home.file.".bikeshed/bin/ecw" = {
        text = ''
          #!/bin/sh
          exec ${config.bikeshed.emacs.package}/bin/emacsclient --reuse-frame -a "" "$@"
        '';
        executable = true;
      };
      home.file.".bikeshed/bin/ec" = {
        text = ''
          #!/bin/sh
          exec ${config.bikeshed.emacs.package}/bin/emacsclient "$@"
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
  );
}
