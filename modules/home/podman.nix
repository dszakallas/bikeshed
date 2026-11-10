{ ... }@ctx:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    mkPackageOption
    types
    optional
    optionals
    ;
  cfg = config.bikeshed.podman;
  # Provides a fake "docker" binary mapping to podman
  dockerCompat =
    pkgs.runCommand "${cfg.package.pname}-docker-compat-${cfg.package.version}"
      {
        nativeBuildInputs = [ pkgs.installShellFiles ];
        outputs = [
          "out"
          "man"
        ];
        inherit (cfg.package) meta;
        preferLocalBuild = true;
      }
      (
        ''
          mkdir -p $out/bin
          ln -s ${cfg.package}/bin/podman $out/bin/docker

          mkdir -p $man/share/man/man1
          for f in ${cfg.package.man}/share/man/man1/*; do
            basename=$(basename $f | sed s/podman/docker/g)
            ln -s $f $man/share/man/man1/$basename
          done
        ''
        + lib.optionalString (pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform) ''
          export HOME=$(mktemp -d) # work around `docker <cmd>`
          installShellCompletion --cmd docker \
            --bash <($out/bin/docker completion bash) \
            --zsh <($out/bin/docker completion zsh) \
            --fish <($out/bin/docker completion fish)
        ''
      );
in
{
  options = {
    bikeshed.podman = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Podman";
      };
      package = mkPackageOption pkgs "podman" { };
      desktop.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Podman Desktop configuration";
      };
      dockerCompat.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Podman Docker compatibility wrapper";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
    ]
    ++ (optional cfg.desktop.enable pkgs.podman-desktop)
    ++ (optional cfg.dockerCompat.enable dockerCompat);
  };
}
