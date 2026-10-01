{
  fetchFromGitHub,
  mkSkill,
  include ? null,
  exclude ? null,
}:
mkSkill {
  name = "wshobson-python-skills";
  version = "2026-09-29";
  src = fetchFromGitHub {
    owner = "wshobson";
    repo = "agents";
    rev = "156b7a5e7a8b93642628a339ee4039c925b34c7f";
    hash = "sha256-LNDpYF5bOeG9GmDW3A2sZv88B00WmxxOAPkzCgkfj3Y=";
  };
  subDir = "plugins/python-development";
  inherit include exclude;
}
