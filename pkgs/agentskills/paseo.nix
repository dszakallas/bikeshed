{
  fetchFromGitHub,
  mkSkill,
  include ? [
    "paseo"
    "paseo-advisor"
    "paseo-committee"
    "paseo-handoff"
    "paseo-help"
    "paseo-plugin"
  ],
  exclude ? null,
}:
mkSkill {
  name = "paseo-skills";
  version = "2026-11-19";
  src = fetchFromGitHub {
    owner = "getpaseo";
    repo = "paseo";
    rev = "95542dbfe6047ad45f9b5a10df5619278e53ac17";
    hash = "sha256-EY8UMNuYRYPkFf2ajsRZgPwBiWl7Uh3/4ZwE//rm2Vg=";
  };
  inherit include exclude;
}
