# Prelude contains common, unopinionated overlays
# that makes it easier to use functions depending on other packages.
{ lib, ... }:
fix: _prev: {
  mkSkill = lib.agents.mkSkill { inherit (fix) stdenvNoCC yq-go; };
}
