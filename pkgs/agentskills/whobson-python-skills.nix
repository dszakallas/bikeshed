{
  fetchFromGitHub,
  mkSkill,
  include ? null,
  exclude ? null,
}:
mkSkill {
  name = "wshobson-python-skills";
  version = "2026-11-18";
  src = fetchFromGitHub {
    owner = "wshobson";
    repo = "agents";
    rev = "42203085cfc5736204bf0f6d436dff7e1da0bf3f";
    hash = "sha256-Azub9g+GEohos2XocajDJPAiQbdbfQFrn76AiDEGXmk=";
  };
  sourceRoot = "plugins/python-development";
  inherit include exclude;
}
