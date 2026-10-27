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
  version = "2026-10-27";
  src = fetchFromGitHub {
    owner = "getpaseo";
    repo = "paseo";
    rev = "6b7d49f0d8d21d01565f9517a8c2a30e2a587e2a";
    hash = "sha256-jHy5Uwz5HM/inHyOtgqjry3liIE4nRKF/gjtKnVS/Yw=";
  };
  inherit include exclude;
}
