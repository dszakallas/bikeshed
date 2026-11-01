{ ... }@ctx:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  agentsLib = ctx.lib.agents;
  cfg = config.bikeshed.agents;

  enabled = lib.filterAttrs (_: h: h.enable) cfg.harnesses;
  plans = lib.mapAttrs (_: agentsLib.mkHarnessPlan pkgs) enabled;

  baseYaml = agentsLib.mkBaseYaml pkgs cfg;
  codeboxInit = agentsLib.mkCodeboxInit pkgs {
    baseSpec = baseYaml;
    overridesDir = cfg.init.overridesDir;
  };
in
{
  key = "bikeshed/home/agents";

  options.bikeshed.agents = {
    enable = mkEnableOption "AI agent tools";
  }
  // agentsLib.agentsOptions pkgs;

  config = mkIf cfg.enable {
    home.packages =
      lib.concatMap (plan: plan.packages) (lib.attrValues plans)
      ++ [ codeboxInit ];

    home.sessionVariables = lib.foldl' (acc: plan: acc // plan.sessionVariables) { } (
      lib.attrValues plans
    );

    home.activation.bikeshedAgentsInit = mkIf cfg.init.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${codeboxInit}/bin/codebox-init
      ''
    );
  };
}
