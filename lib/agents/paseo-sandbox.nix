{
  lib,
  home-manager ? null,
  ctx ? { },
}:
pkgs:
{
  name ? "paseo-sandbox",
  tag ? "0.1.0",
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
      throw "mkPaseoSandboxImage: home-manager input must be provided";

  homeConfig = hm.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = {
      inherit (pkgs.stdenv) hostPlatform;
      system = pkgs.stdenv.hostPlatform.system;
    }
    // extraSpecialArgs;
    modules = [
      {
        home = {
          username = user;
          homeDirectory = home;
          stateVersion = "25.05";
        };
      }
    ]
    ++ modules;
  };

  shell =
    if homeConfig.config.programs.zsh.enable then
      "${pkgs.zsh}/bin/zsh"
    else
      "${pkgs.bashInteractive}/bin/bash";

  entrypointScript = pkgs.writeShellScriptBin "paseo-sandbox-entrypoint" ''
    set -eu

    mkdir -m 1777 -p /tmp 2>/dev/null || true
    mkdir -m 0755 -p ${home} 2>/dev/null || true

    ${homeConfig.activationPackage}/activate

    if [ "$#" -gt 0 ]; then
      exec "$@"
    fi

    exec paseo-server
  '';

  entrypoint = pkgs.runCommand "paseo-sandbox-entrypoint-wrapper" { } ''
    mkdir -p $out/bin
    ln -s ${entrypointScript}/bin/paseo-sandbox-entrypoint $out/bin/paseo-sandbox-entrypoint
    ln -s ${entrypointScript}/bin/paseo-sandbox-entrypoint $out/bin/codebox-entrypoint
  '';
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
    mkdir -m 0755 -p home/${user} etc/bikeshed/agents/init
    chown -R ${toString uid}:${toString gid} home/${user} etc/bikeshed/agents/init

    # Grant the user full ownership of the Nix store and DB for rootless package management
    mkdir -p nix/store nix/var/nix/profiles/per-user/${user} nix/var/nix/gcroots/per-user/${user} etc/nix
    chown -R ${toString uid}:${toString gid} nix etc/nix
    chmod -R u+w,g+w nix/var
  '';

  config = {
    User = "${toString uid}:${toString gid}";
    Entrypoint = [ "paseo-sandbox-entrypoint" ];
    WorkingDir = "${home}";
    Env = [
      "PATH=${home}/.bikeshed/bin:${home}/.local/bin:${home}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/bin:/usr/bin"
      "USER=${user}"
      "HOME=${home}"
      "SHELL=${shell}"
      "NIX_PAGER=cat"
      "NIX_PATH=nixpkgs=channel:nixos-unstable"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "PASEO_HOME=${home}/paseo"
      "PASEO_LISTEN=0.0.0.0:6767"
      "PASEO_WEB_UI_ENABLED=true"
      "PASEO_LOG_FORMAT=json"
      "PASEO_LOG_LEVEL=info"
      # Skip the local speech model download.
      "PASEO_DICTATION_ENABLED=false"
      "PASEO_VOICE_MODE_ENABLED=false"
    ]
    ++ lib.mapAttrsToList (k: v: "${k}=${v}") homeConfig.config.home.sessionVariables;
    ExposedPorts = {
      "6767/tcp" = { };
    };
    Volumes = {
      "${home}" = { };
    };
  };
}
