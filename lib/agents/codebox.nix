{
  lib,
  harnessConfig,
  assembleSkills,
  home-manager ? null,
  ctx ? { },
}:
pkgs:
{
  name ? "codebox",
  tag ? "0.1.0",
  agents ? { },
  paseo,
  extraPackages ? [ ],
  user ? "coder",
  uid ? 10001,
  gid ? 10001,
  home ? "/home/${user}",
  modules ? [ ],
  extraSpecialArgs ? { },
  homeManager ? home-manager,
}:

assert uid > 10000;

let
  inherit (pkgs) dockerTools;

  hm =
    if homeManager != null then
      homeManager
    else if ctx ? home-manager then
      ctx.home-manager
    else
      throw "mkCodeboxImage: home-manager input must be provided";

  homeConfig = hm.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = {
      inherit (pkgs.stdenv) hostPlatform;
      system = pkgs.stdenv.hostPlatform.system;
    }
    // extraSpecialArgs;
    modules = [
      (import ../../modules/home/agents ctx)
      {
        home = {
          username = user;
          homeDirectory = home;
          stateVersion = "25.05";
        };
        bikeshed.agents = {
          # Declare every known harness with its defaults. Instances stay
          # disabled unless the caller (or a mounted initializer) enables them.
          harnesses = lib.genAttrs harnessConfig.configurableNames (_: { });
          skills.enable = lib.mkDefault true;
          init.overridesDir = lib.mkDefault "/etc/bikeshed/agents/init:.config/bikeshed/agents/init";
        };
      }
      (lib.optionalAttrs (agents != { }) {
        bikeshed.agents = agents;
      })
    ]
    ++ modules;
  };

  cfg = homeConfig.config.bikeshed.agents;

  plans = lib.mapAttrs (_: harnessConfig.mkHarnessPlan pkgs) cfg.harnesses;
  enabledInstances = lib.filterAttrs (n: _: cfg.harnesses.${n}.enable) cfg.harnesses;
  enabledPlans = lib.filterAttrs (n: _: enabledInstances ? ${n}) plans;

  shell =
    if homeConfig.config.programs.zsh.enable then
      "${pkgs.zsh}/bin/zsh"
    else
      "${pkgs.bashInteractive}/bin/bash";

  entrypoint = pkgs.writeShellScriptBin "codebox-entrypoint" ''
    set -eu

    mkdir -m 1777 -p /tmp 2>/dev/null || true
    mkdir -m 0755 -p ${home} /workspace 2>/dev/null || true

    ${homeConfig.activationPackage}/activate

    if [ "$#" -gt 0 ]; then
      exec "$@"
    fi

    exec paseo-server
  '';

  sessionVariables = lib.concatMapAttrs (
    _: plan: lib.mapAttrs (_: lib.replaceStrings [ "$HOME" ] [ home ]) plan.sessionVariables
  ) enabledPlans;
in
dockerTools.buildLayeredImage {
  includeNixDB = true;
  inherit name tag;

  contents = [
    (pkgs.buildEnv {
      name = "image-root";
      ignoreCollisions = true;
      paths =
        with pkgs;
        [
          bashInteractive
          cacert
          coreutils
          dockerTools.binSh
          dockerTools.caCertificates
          dockerTools.usrBinEnv
          entrypoint
          homeConfig.activationPackage
          iana-etc
          nix
          paseo
          (fakeNss.override {
            extraPasswdLines = [
              "${user}:x:${toString uid}:${toString gid}:Coder user:${home}:${shell}"
            ];
            extraGroupLines = [
              "${user}:x:${toString gid}:"
            ];
          })
          (writeTextDir "etc/nix/nix.conf" ''
            experimental-features = nix-command flakes
            sandbox = false
            filter-syscalls = false
            build-users-group =
            substituters = https://cache.nixos.org/ https://devenv.cachix.org
            trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
            trusted-users = root ${user}
          '')
        ]
        ++ homeConfig.config.home.packages
        ++ extraPackages;
      pathsToLink = [
        "/bin"
        "/etc"
        "/share"
        "/usr"
      ];
    })
  ];

  fakeRootCommands = ''
    mkdir -m 1777 -p tmp
    mkdir -m 0755 -p home/${user} workspace etc/bikeshed/agents/init
    chown -R ${toString uid}:${toString gid} home/${user} workspace etc/bikeshed/agents/init

    # Grant the user full ownership of the Nix store and DB for rootless package management
    mkdir -p nix/store nix/var/nix/profiles/per-user/${user} nix/var/nix/gcroots/per-user/${user} etc/nix
    chown -R ${toString uid}:${toString gid} nix etc/nix
    chmod -R u+w,g+w nix/var
  '';

  config = {
    User = "${toString uid}:${toString gid}";
    Entrypoint = [ "codebox-entrypoint" ];
    WorkingDir = "/workspace";
    Env = [
      "PATH=${home}/.bikeshed/bin:${home}/.local/bin:${home}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/bin:/usr/bin"
      "USER=${user}"
      "HOME=${home}"
      "SHELL=${shell}"
      "NIX_PAGER=cat"
      "NIX_PATH=nixpkgs=channel:nixos-unstable"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "PASEO_HOME=${home}/.paseo"
      "PASEO_LISTEN=0.0.0.0:6767"
      "PASEO_WEB_UI_ENABLED=true"
      "PASEO_LOG_FORMAT=json"
      "PASEO_LOG_LEVEL=info"
      # Skip the local speech model download.
      "PASEO_DICTATION_ENABLED=false"
      "PASEO_VOICE_MODE_ENABLED=false"
    ]
    ++ lib.mapAttrsToList (k: v: "${k}=${v}") homeConfig.config.home.sessionVariables
    ++ lib.mapAttrsToList (k: v: "${k}=${v}") sessionVariables;
    ExposedPorts = {
      "6767/tcp" = { };
    };
    Volumes = {
      "${home}" = { };
      "/workspace" = { };
    };
  };
}
