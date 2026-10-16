{
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  stdenvNoCC,
  mkSkill,
  include ? null,
  exclude ? null,
}:
let
  rawSrc = fetchFromGitHub {
    owner = "Egonex-AI";
    repo = "Understand-Anything";
    rev = "f2d0164f72fe678805c34245a6df36acededfebd";
    hash = "sha256-8QJy9PJKv9fSDzX9cPPmoqwM34s5JVT/FjcV50dfONE=";
  };

  # Exclude packages/viewer from pnpm workspace before dependency fetching
  # because the vendored pnpm-lock.yaml does not contain an importer for it.
  patchedSrc = stdenvNoCC.mkDerivation {
    name = "understand-anything-source";
    src = rawSrc;
    dontBuild = true;
    postPatch = ''
      substituteInPlace understand-anything-plugin/pnpm-workspace.yaml \
        --replace-fail '  - "packages/*"' $'  - "packages/*"\n  - "!packages/viewer"'
    '';
    installPhase = ''
      cp -r . $out
    '';
  };

  pluginSrc = "${patchedSrc}/understand-anything-plugin";

  pnpmDeps = fetchPnpmDeps {
    pname = "understand-anything";
    src = pluginSrc;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-yQS63+e67iv+dBEmFKXKw3fmAwumUg8fLQ28Rdd7WDg=";
  };
in
mkSkill {
  name = "understand-anything";
  version = "2026-10-12";
  src = pluginSrc;
  preserveSourceRoot = true;
  inherit pnpmDeps include exclude;

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild
    pnpm --filter @understand-anything/core build
    runHook postBuild
  '';
}
