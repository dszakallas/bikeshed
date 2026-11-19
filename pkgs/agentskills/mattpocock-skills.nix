{
  fetchFromGitHub,
  mkSkill,
  include ? [
    "code-review"
    "codebase-design"
    "domain-modeling"
    "tdd"
    "prototype"
    "diagnosing-bugs"
  ],
  exclude ? null,
}:
mkSkill {
  name = "mattpocock-skills";
  version = "2026-11-19";
  src = fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "abeeaf95660ba9e8b7c753eb38f441ca707a8823";
    hash = "sha256-fc5+qmchp1IQ/rQP1olWKC1eC4VdYhaB7YYzC3+JBe0=";
  };
  inherit include exclude;
}
