{ ... }:
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
    ;
in
{
  options = {
    bikeshed = {
      devenv = {
        enable = mkEnableOption "devenv";
      };
      direnv = {
        enable = mkEnableOption "direnv";
      };
    };
  };

  config = {
    home = {
      packages = mkIf config.bikeshed.devenv.enable [ pkgs.devenv ];
      shellAliases = mkIf config.bikeshed.devenv.enable {
        devsh = "devenv shell --no-tui --quiet";
      };
    };

    programs = {
      direnv = mkIf config.bikeshed.direnv.enable {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      zsh.oh-my-zsh.plugins = mkIf config.bikeshed.direnv.enable [ "direnv" ];
    };
  };
}
