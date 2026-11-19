{
  fetchFromGitHub,
  mkSkill,
  include ? null,
  exclude ? null,
}:
# Pinned to the same tag nixpkgs builds the gh-stack extension from, so the
# skill documents the CLI that is actually installed. Bump both together.
mkSkill {
  name = "gh-stack";
  version = "0.3.0";
  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-stack";
    rev = "v0.3.0";
    hash = "sha256-dENuxVuz68Y7P8WW5C7pzVbfJRxGMGIKQ2AnWrTacOs=";
  };
  inherit include exclude;
}
