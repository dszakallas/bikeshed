{ self, packages, ... }@ctx:
{
  config,
  lib,
  pkgs,
  system,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    ;
  moduleName = "bikeshed/home/gpg";
in
{
  options =
    let
      inherit (types)
        str
        ;
    in
    {
      bikeshed.gpg.enable = mkEnableOption "GPG goodies";
      bikeshed.gpg.defaultKey = mkOption {
        type = str;
        description = "Default GPG key to use";
        default = "";
      };
    };
  config = {
    home = {
      packages = [ pkgs.gnupg ];
      file.".gnupg/gpg-agent.conf" = mkIf config.bikeshed.gpg.enable {
        text = ctx.lib.textRegion {
          name = moduleName;
          content = ''
            default-cache-ttl 600
            max-cache-ttl 7200
            enable-ssh-support
          '';
        };
      };
      file.".gnupg/gpg.conf" = mkIf config.bikeshed.gpg.enable {
        text = ctx.lib.textRegion {
          name = moduleName;
          content = ''
            auto-key-retrieve
            no-emit-version
            personal-digest-preferences SHA512
            cert-digest-algo SHA512
            default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
          ''
          + (
            if (config.bikeshed.gpg.defaultKey != "") then
              ''
                default-key ${config.bikeshed.gpg.defaultKey};
              ''
            else
              ""
          );
        };
      };
    };
  };
}
