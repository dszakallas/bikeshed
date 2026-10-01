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
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-stack";
    rev = "v0.1.0";
    hash = "sha256-48JkOeqbvHlCZ2u3LnwJymw55xMQWLTPJLDbV44clGI=";
  };
  inherit include exclude;
}
