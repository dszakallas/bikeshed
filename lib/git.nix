{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;
  inherit (lib) mkOption types;

  # Shared submodule type for git credential configuration, reused by
  # bikeshed.git.authentication.rules.*.credential and by userPresets that
  # want to expose their own configurable credential block.
  credentialType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to configure git credentials for this prefix.";
      };
      username = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The credential username. If null, no username is set.";
      };
      helper = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The credential helper. If null, no helper is set.";
      };
    };
  };
in
{
  git = {
    inherit credentialType;
  };
}
