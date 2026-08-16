{ ... }@ctx:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;

  cfg = config.services.litellm;
  settingsFormat = pkgs.formats.yaml { };

  tiktokenEncodings = {
    cl100k_base = {
      url = "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken";
      hash = "sha256-Ijkht27pm96ZW3/3OFE+7xAPtR0YyTWXoRO8/+hlsqc=";
    };
  };

  tiktokenCacheEntries = lib.mapAttrsToList (
    _: encoding:
    let
      cacheKey = builtins.hashString "sha1" encoding.url;
      sourceFile = pkgs.fetchurl {
        inherit (encoding) url hash;
      };
    in
    {
      inherit cacheKey sourceFile;
    }
  ) tiktokenEncodings;

  seedTiktokenCacheScript = pkgs.writeShellScript "litellm-seed-tiktoken-cache" ''
    set -eu

    mkdir -p "$CUSTOM_TIKTOKEN_CACHE_DIR"

    ${lib.concatMapStringsSep "\n" (entry: ''
      ln -sf ${entry.sourceFile} "$CUSTOM_TIKTOKEN_CACHE_DIR/${entry.cacheKey}"
    '') tiktokenCacheEntries}
  '';

  configFile = settingsFormat.generate "config.yaml" cfg.settings;

  startScript = pkgs.writeShellScript "litellm-start" ''
    set -eu

    mkdir -p "${cfg.stateDir}/ui" "${cfg.stateDir}/tiktoken-cache"
    chmod -R u+rwX "${cfg.stateDir}/ui"

    export CUSTOM_TIKTOKEN_CACHE_DIR="${cfg.stateDir}/tiktoken-cache"
    export LITELLM_NON_ROOT="true"
    export LITELLM_UI_PATH="${cfg.stateDir}/ui"

    ${lib.concatMapStringsSep "\n" (k: "export ${k}=${lib.escapeShellArg cfg.environment.${k}}") (
      builtins.attrNames cfg.environment
    )}

    ${lib.optionalString (cfg.environmentFile != null) ''
      if [ -f ${lib.escapeShellArg (toString cfg.environmentFile)} ]; then
        set -o allexport
        source ${lib.escapeShellArg (toString cfg.environmentFile)}
        set +o allexport
      fi
    ''}

    if [ -n "''${DATABASE_URL:-}" ]; then
      if [[ "$DATABASE_URL" =~ postgresql://([^@]+)@([^:/]+)(:([0-9]+))?/([^?]+) ]]; then
        PG_USER="''${BASH_REMATCH[1]}"
        PG_HOST="''${BASH_REMATCH[2]}"
        PG_PORT="''${BASH_REMATCH[4]:-5432}"
        PG_DB="''${BASH_REMATCH[5]}"
        if [ "$PG_HOST" = "127.0.0.1" ] || [ "$PG_HOST" = "localhost" ]; then
          until ${pkgs.postgresql}/bin/pg_isready -h "$PG_HOST" -p "$PG_PORT" -U postgres; do
            sleep 1
          done
          ${pkgs.postgresql}/bin/psql -h "$PG_HOST" -p "$PG_PORT" -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname = '$PG_USER'" | grep -q 1 || ${pkgs.postgresql}/bin/createuser -h "$PG_HOST" -p "$PG_PORT" -U postgres -s "$PG_USER"
          ${pkgs.postgresql}/bin/psql -h "$PG_HOST" -p "$PG_PORT" -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$PG_DB'" | grep -q 1 || ${pkgs.postgresql}/bin/createdb -h "$PG_HOST" -p "$PG_PORT" -U postgres -O "$PG_USER" "$PG_DB"
        fi
      fi

      mkdir -p "${cfg.stateDir}/site-packages"
      if [ ! -d "${cfg.stateDir}/site-packages/prisma" ]; then
        cp -r "${pkgs.python3Packages.prisma}/${pkgs.python3.sitePackages}/prisma" "${cfg.stateDir}/site-packages/prisma"
        chmod -R u+w "${cfg.stateDir}/site-packages"
      fi

      export PYTHONPATH="${cfg.stateDir}/site-packages:''${PYTHONPATH:-}"
      export PRISMA_QUERY_ENGINE_BINARY="${pkgs.prisma-engines_6}/bin/query-engine"
      export PRISMA_SCHEMA_ENGINE_BINARY="${pkgs.prisma-engines_6}/bin/schema-engine"
      export PRISMA_FMT_BINARY="${pkgs.prisma-engines_6}/bin/prisma-fmt"
      export PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING="1"

      ${pkgs.python3Packages.prisma}/bin/prisma py generate --schema "${cfg.package}/${pkgs.python3.sitePackages}/litellm/proxy/schema.prisma"
    fi

    ${seedTiktokenCacheScript}

    exec ${lib.getExe cfg.package} --host ${lib.escapeShellArg cfg.host} --port ${toString cfg.port} --config ${configFile}
  '';
in
{
  options = {
    services.litellm = {
      enable = lib.mkEnableOption "LiteLLM server";
      package = lib.mkPackageOption pkgs "litellm" { };

      stateDir = lib.mkOption {
        type = types.path;
        default = "/var/lib/litellm";
        example = "/var/lib/litellm";
        description = "State directory of LiteLLM.";
      };

      host = lib.mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = ''
          The host address which the LiteLLM server HTTP interface listens to.
        '';
      };

      port = lib.mkOption {
        type = types.port;
        default = 8080;
        example = 11111;
        description = ''
          Which port the LiteLLM server listens to.
        '';
      };

      settings = lib.mkOption {
        type = types.submodule {
          freeformType = settingsFormat.type;
          options = {
            model_list = lib.mkOption {
              type = settingsFormat.type;
              description = ''
                List of supported models on the server, with model-specific configs.
              '';
              default = [ ];
            };
            router_settings = lib.mkOption {
              type = settingsFormat.type;
              description = ''
                LiteLLM Router settings
              '';
              default = { };
            };

            litellm_settings = lib.mkOption {
              type = settingsFormat.type;
              description = ''
                LiteLLM Module settings
              '';
              default = { };
            };

            general_settings = lib.mkOption {
              type = settingsFormat.type;
              description = ''
                LiteLLM Server settings
              '';
              default = { };
            };

            environment_variables = lib.mkOption {
              type = settingsFormat.type;
              description = ''
                Environment variables to pass to LiteLLM
              '';
              default = { };
            };
          };
        };
        default = { };
        description = ''
          Configuration for LiteLLM.
          See <https://docs.litellm.ai/docs/proxy/configs> for more.
        '';
      };

      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = {
          SCARF_NO_ANALYTICS = "True";
          DO_NOT_TRACK = "True";
          ANONYMIZED_TELEMETRY = "False";
        };
        example = ''
          {
            NO_DOCS = "True";
          }
        '';
        description = ''
          Extra environment variables for LiteLLM.
        '';
      };

      environmentFile = lib.mkOption {
        description = ''
          Environment file to be passed to the launchd service.
          Useful for passing secrets to the service to prevent them from being
          world-readable in the Nix store.
        '';
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/var/lib/secrets/liteLLMSecrets";
      };

      user = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "User account under which LiteLLM runs.";
      };

      group = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Group under which LiteLLM runs.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.litellm = {
      serviceConfig = {
        ProgramArguments = [ (toString startScript) ];
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = cfg.stateDir;
        StandardOutPath = "${cfg.stateDir}/litellm.log";
        StandardErrorPath = "${cfg.stateDir}/litellm.log";
      }
      // lib.optionalAttrs (cfg.user != null) { UserName = cfg.user; }
      // lib.optionalAttrs (cfg.group != null) { GroupName = cfg.group; };
    };
  };
}
