{ self, ... }@ctx:
{
  pkgs,
  lib,
  config,
  system,
  nixConfig,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkOption
    mkEnableOption
    mkIf
    types
    ;
in
{
  options = {
    bikeshed.nix = {
      enable = mkEnableOption "nix configuration";
      pinnedFlakes = mkOption {
        type = types.attrs;
        default = { };
        description = "Flakes to pin in the nix registry. The keys are the short (angle bracket) names to use, and the values are flake input attributes. Useful so for example you can refer to the 'uv2nix' flake as <uv2nix> using the system installed version.";
      };
    };
  };
  config = {
    environment.shells = with pkgs; [
      bash
      zsh
    ];

    environment.systemPackages = with pkgs; [
      curl
      vim
      git
      gnupg
    ];
    # The platform the configuration will be used on.
    nixpkgs.hostPlatform = system;

    nix = mkIf config.bikeshed.nix.enable {
      settings = nixConfig;

      registry = mapAttrs (name: value: {
        exact = true;
        from = {
          id = name;
          type = "indirect";
        };
        flake = value;
      }) config.bikeshed.nix.pinnedFlakes;

      nixPath = map (v: "${v}=flake:${v}") (builtins.attrNames config.bikeshed.nix.pinnedFlakes);
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm.bak";
    };

    environment.etc."hosts" = {
      # TODO Linking the hosts file to /etc/hosts in darwin doesn't work.
      enable = !pkgs.stdenv.hostPlatform.isDarwin;
      text = ctx.lib.textRegion {
        name = "davids-dotfiles/default";
        content = (builtins.readFile ./hosts);
      };
    };
  };
}
