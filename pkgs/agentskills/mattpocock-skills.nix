{
  fetchFromGitHub,
  mkSkill,
  include ? [
    "code-review"
    "codebase-design"
    "resolving-merge-conflicts"
    "domain-modeling"
    "tdd"
    "prototype"
    "diagnosing-bugs"
  ],
  exclude ? null,
}:
mkSkill {
  name = "mattpocock-skills";
  version = "2026-09-29";
  src = fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "d81f3a183412e71a5b1e84ca21bc1a35eea03a60";
    hash = "sha256-zQ/wVrcHjIC+UjP4nDw3HARMqZd6LIDFmHKlp8AADYI=";
  };
  inherit include exclude;
}
