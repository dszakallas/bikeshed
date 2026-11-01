{ ... }@ctx:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
in
{
  options = {
    bikeshed.podman = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Podman Docker wrapper and shell alias";
      };
    };
  };

  config = mkIf config.bikeshed.podman.enable {
    home = {
      # in some shell scripts, alias doesn't work, so we use a wrapper script
      file.".bikeshed/bin/docker" = {
        text = ''
          #!/bin/sh
          exec podman "$@"
        '';
        executable = true;
      };
      shellAliases = {
        docker = "podman";
      };
    };
  };
}
