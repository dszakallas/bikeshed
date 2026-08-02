{ ... }:
{
  pkgs,
  config,
  lib,
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
    bikeshed.k8stools = {
      enable = mkEnableOption "Kubernetes tools";
    };
  };
  config = mkIf config.bikeshed.k8stools.enable {
    home.packages = with pkgs; [
      k9s
      kind
      kubecolor
      kubectl
      kubernetes-helm
      kustomize
      oras
      skopeo
    ];
    programs.zsh.shellAliases = {
      k = "kubecolor";
    };
  };
}
