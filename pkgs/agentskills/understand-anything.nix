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

  # Exclude packages/viewer from the pnpm workspace before dependency fetching:
  # the vendored pnpm-lock.yaml has no importer for it. The viewer has no
  # dependencies of its own, so it is built directly from its build script.
  #
  # Patch the dashboard skill's fast path to prefer the bundled viewer over the
  # GitHub release tarball. No viewer asset is published for this version (the
  # download 404s) and the Vite dev-server fallback cannot run from the
  # read-only store.
  patchedSrc = stdenvNoCC.mkDerivation {
    name = "understand-anything-source";
    src = rawSrc;
    dontBuild = true;
    postPatch = ''
      substituteInPlace understand-anything-plugin/pnpm-workspace.yaml \
        --replace-fail '  - "packages/*"' $'  - "packages/*"\n  - "!packages/viewer"'

      substituteInPlace understand-anything-plugin/skills/understand-dashboard/SKILL.md \
        --replace-fail \
        'npx --yes "$VIEWER_URL" "$PROJECT_DIR"' \
        'if [ -f "$PLUGIN_ROOT/packages/viewer/bin/viewer.mjs" ]; then
         node "$PLUGIN_ROOT/packages/viewer/bin/viewer.mjs" "$PROJECT_DIR"
       else
         npx --yes "$VIEWER_URL" "$PROJECT_DIR"
       fi'
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

  # build.mjs builds core and dashboard, then embeds the dashboard frontend and
  # core's staleness module into packages/viewer/{dist,bin/dist} so the bundled
  # viewer can serve the graph without network access or a build step.
  buildPhase = ''
    runHook preBuild
    node packages/viewer/build.mjs
    runHook postBuild
  '';
}
