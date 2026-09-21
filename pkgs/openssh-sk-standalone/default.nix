# Standalone build of the OpenSSH security key support library
# Needed on macOS where the system OpenSSH does not include it
# https://github.com/Yubico/libfido2/issues/464
# https://github.com/openssh/openssh-portable/commit/ca0697a90e5720ba4d76cb0ae9d5572b5260a16c
{
  libfido2,
  zlib,
  autoconf,
  automake,
  stdenv,
  fetchFromGitHub,
  lib,
  pkg-config,
}:
stdenv.mkDerivation rec {

  pname = "openssh-sk-standalone";
  version = "V_10_5_P1";

  src = fetchFromGitHub {
    owner = "openssh";
    repo = "openssh-portable";
    rev = version;
    hash = "sha256-eXQH/a8KOO+vfk0vEy3Zwce3C93J9Sa9W4TEQqX8U4g=";
  };

  preConfigure = ''
    # Setting LD causes `configure' and `make' to disagree about which linker
    # to use: `configure' wants `gcc', but `make' wants `ld'.
    unset LD
  '';

  nativeBuildInputs = [
    autoconf
    automake
    pkg-config
  ];

  buildInputs = [
    libfido2
    zlib
  ];

  configurePhase = ''
    ./configure --prefix=$out --with-security-key-standalone
  '';

  buildPhase = ''
    # Only build what's needed for the security key library
    target=$(grep -Po '(?<=SK_STANDALONE=).*' Makefile)
    make openbsd-compat/libopenbsd-compat.a libssh-pic.a $target
  '';

  installPhase = ''
    target=$(grep -Po '(?<=SK_STANDALONE=).*' Makefile)
    mkdir -p $out/lib
    cp $target $out/lib/
  '';
}
