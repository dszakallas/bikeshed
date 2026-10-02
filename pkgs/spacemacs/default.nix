{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "spacemacs";
  version = "2026-09-26-develop";
  src = fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "9bc6300f2409582f2dacd4aacdc12a175d213d54";
    hash = "sha256-FeAJjPQXRjs9pt9/gnilkoYohNf7LlhB3KUUgUMK9qk=";
  };

  patches = [
    ./quelpa-build-writable.diff
  ];

  installPhase = ''
    mkdir -p $out/share/spacemacs
    cp -r * .lock $out/share/spacemacs
  '';
}
