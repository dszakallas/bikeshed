{ ... }:
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
    mkIf
    mkOption
    types
    ;
  brew = config.bikeshed.brew;
in
{
  options = {
    bikeshed.brew = {
      enable = mkEnableOption "Homebrew integration";
      prefix = mkOption {
        type = types.str;
        default = "/opt/homebrew";
        description = "Homebrew installation prefix";
      };
    };
  };

  config.targets.darwin.defaults = {
    NSGlobalDomain = {
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;

      AppleMetricUnits = true;
      AppleLocale = "en_US";
    };

    "com.apple.desktopservices" = {
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };

    "com.apple.finder" = {
      AppleShowAllFiles = true;
      ShowPathBar = true;
      ShowStatusBar = true;
    };

  };

  config.programs.zsh.envExtra = mkIf brew.enable ''
    export HOMEBREW_PREFIX="${brew.prefix}"
    export HOMEBREW_NO_ENV_HINTS="1"
    export HOMEBREW_AUTO_UPDATE_SECS="604800"
    export PATH="${brew.prefix}/bin:$PATH"
    export PATH="${brew.prefix}/opt/gnu-getopt/bin:$PATH"
  '';

  config.programs.zsh.initContent = mkIf brew.enable ''
    if type brew &>/dev/null; then
      FPATH=$HOMEBREW_PREFIX/share/zsh/site-functions:$FPATH
      autoload -Uz compinit
      compinit
    fi
  '';

  config.programs.bash.profileExtra = mkIf brew.enable ''
    export HOMEBREW_PREFIX="${brew.prefix}"
    export HOMEBREW_NO_ENV_HINTS="1"
    export HOMEBREW_AUTO_UPDATE_SECS="604800"
    export PATH="${brew.prefix}/bin:$PATH"
    export PATH="${brew.prefix}/opt/gnu-getopt/bin:$PATH"
  '';

  config.programs.bash.bashrcExtra = mkIf brew.enable ''
    if [[ -r "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]]; then
      source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
    else
      for COMPLETION in "$HOMEBREW_PREFIX/etc/bash_completion.d/"*; do
        [[ -r "''${COMPLETION}" ]] && source "''${COMPLETION}"
      done
    fi
  '';
}
