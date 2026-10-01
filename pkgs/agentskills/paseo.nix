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
  version = "2026-10-01";
  src = fetchFromGitHub {
    owner = "getpaseo";
    repo = "paseo";
    rev = "06213e49bf42442d208df405ed4c215e1e45f690";
    hash = "sha256-fsIU7hKYMurTw6d45q/8spvxaYzPdSpd0qP1hzYjZsI=";
  };
  inherit include exclude;
}
