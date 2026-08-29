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
    concatStringsSep
    flatten
    mapAttrs
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    mkOption
    types
    ;
  moduleName = "bikeshed/home/ssh";
  # Needed on darwin because the system ssh does not ship with sk-libfido2.dylib
  standaloneFIDO2 = "${
    packages.${system}.openssh-sk-standalone
  }/lib/sk-libfido2${hostPlatform.extensions.sharedLibrary}";
in
{
  options =
    let
      inherit (types)
        lines
        attrsOf
        nullOr
        str
        submodule
        bool
        ;
    in
    {
      bikeshed.ssh.enable = mkEnableOption "SSH goodies";
      bikeshed.ssh.agent.enable = mkEnableOption "ssh-agent management";
      bikeshed.ssh.knownHostsLines = mkOption {
        description = "Managed known_host file lines";
        type = lines;
        default = "";
      };
      bikeshed.ssh.matchBlocks = mkOption {
        type = attrsOf (submodule {
          freeformType = types.attrsOf types.anything;
          options = {
            applyDefaults = mkOption {
              type = bool;
              description = "Whether to apply default settings";
              default = true;
            };
            isFIDO2 = mkOption {
              type = bool;
              description = "Whether to use FIDO2 authentication";
              default = false;
            };
            match = mkOption {
              type = nullOr str;
              description = "SSH Match criteria (sets the block header)";
              default = null;
            };
          };
        });
        description = "SSH config blocks";
        default = { };
      };
    };
  config = {
    launchd.agents = mkIf hostPlatform.isDarwin {
      # Uber-hacky way to redirect the default ssh-agent socket to our agent
      # We can't use the standard /System/Library/LaunchAgents/com.openssh.ssh-agent.plist
      # because we need to customize the arguments to support FIDO2
      # SSH_AUTH_SOCK will always be allocated (unless someone turned off SIP and unloaded the system ssh-agent)
      "com.openssh.ssh-agent" = mkIf (config.bikeshed.ssh.enable) {
        enable = config.bikeshed.ssh.agent.enable;
        config = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            (concatStringsSep " " [
              "rm -f $SSH_AUTH_SOCK;"
              "exec /usr/bin/ssh-agent"
              "-d"
              "-a $SSH_AUTH_SOCK"
              "-P ${standaloneFIDO2}"
            ])
          ];
          EnableTransactions = true;
          RunAtLoad = true;
        };
      };
    };
    home.file.".bikeshed/share/ssh/known_hosts" = mkIf config.bikeshed.ssh.enable {
      text = config.bikeshed.ssh.knownHostsLines;
    };
    programs = {
      ssh = mkIf config.bikeshed.ssh.enable (
        let
          wildcardHostConfig = {
            ForwardAgent = false;
            AddKeysToAgent = "no";
            Compression = false;
            ServerAliveInterval = 0;
            ServerAliveCountMax = 3;
            HashKnownHosts = false;
            # default ~/.ssh/known_hosts is unmanaged. ~/.bikeshed/share/ssh/known_hosts is managed by this module
            UserKnownHostsFile = "~/.ssh/known_hosts ~/.bikeshed/share/ssh/known_hosts";
            ControlMaster = "no";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "no";
          };
        in
        {
          enable = true;
          # trace: warning: davidszakallas profile: `programs.ssh` default values will be removed in the future.
          enableDefaultConfig = false;
          # Unmanaged local overrides
          includes = [ "~/.local/share/ssh/config" ];

          settings = mapAttrs (
            n:
            {
              applyDefaults ? true,
              isFIDO2 ? false,
              match ? null,
              ...
            }@v:
            let
              identityFile = v.IdentityFile or [ ];
              hasIdentityFile = identityFile != [ ] && identityFile != null && identityFile != "";
            in
            mkMerge [
              (mkIf (n == "*") wildcardHostConfig)
              (if match != null then { header = "Match ${match}"; } else { })
              (builtins.removeAttrs v [
                "applyDefaults"
                "isFIDO2"
                "match"
              ])
              (mkIf applyDefaults {
                IdentitiesOnly = mkIf hasIdentityFile (mkForce true);
                AddKeysToAgent = mkIf hasIdentityFile (mkForce "yes");
                # the default macOS ssh does not ship sk-libfido2 so we need to use a standalone library
                UseKeychain = mkIf (pkgs.stdenv.isDarwin && hasIdentityFile) "yes";
              })
              (mkIf (hasIdentityFile && isFIDO2 && pkgs.stdenv.isDarwin) {
                SecurityKeyProvider = "${standaloneFIDO2}";
              })
            ]
          ) ({ "*" = { }; } // config.bikeshed.ssh.matchBlocks);
        }
      );
    };
  };
}
