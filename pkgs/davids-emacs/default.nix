{
  emacs,
  lib,
  stdenv,
  withNS ? stdenv.hostPlatform.isDarwin,
  withMailutils ? false,
  # Has been reported not-working in macOS 15.4:
  # https://github.com/NixOS/nixpkgs/issues/395169
  # however, I have not seen any issues on macOS 15.5
  withNativeCompilation ? true,
}:
# These patches mainly fix GUI issues on macOS, I sourced them from
# https://github.com/d12frosted/homebrew-emacs-plus
let
  emacsMajor = lib.versions.major (lib.getVersion emacs);
  nsPatches =
    {
      "30" = [
        ./patches/emacs-30/fix-window-role.patch
        ./patches/emacs-30/round-undecorated-frame.patch
        ./patches/emacs-30/system-appearance.patch
      ];
      "31" = [
        ./patches/emacs-31/fix-ns-scroll-crash.patch
        ./patches/emacs-31/fix-ns-x-colors.patch
        ./patches/emacs-31/round-undecorated-frame.patch
        ./patches/emacs-31/system-appearance.patch
      ];
    }
    .${emacsMajor} or (throw "davids-emacs only supports Emacs 30 and 31");
in
(emacs.override {
  inherit withMailutils withNS withNativeCompilation;
}).overrideAttrs
  (prev: {
    patches = (prev.patches or [ ]) ++ lib.optionals withNS nsPatches;
    # Add macOS application bundle for EmacsClient
    postInstall =
      let
        info = lib.generators.toPlist { escape = true; } {
          CFBundleExecutable = "EmacsClient";
          CFBundleIdentifier = "eu.szakallas.emacsclient";
          CFBundleName = "EmacsClient";
          CFBundleVersion = prev.version;
          CFBundleShortVersionString = prev.version;
          CFBundlePackageType = "APPL";
          CFBundleIconFile = "Emacs.icns";
        };
      in
      lib.concatStrings [
        (prev.postInstall or "")
        (lib.optionalString withNS ''
          mkdir -p $out/Applications/EmacsClient.app/Contents/MacOS
          cat << EOF > $out/Applications/EmacsClient.app/Contents/MacOS/EmacsClient
          #!/bin/sh
          exec $out/bin/emacsclient --reuse-frame "$@" &>/dev/null 2>&1 --alternate-editor="" &
          EOF
          chmod +x $out/Applications/EmacsClient.app/Contents/MacOS/EmacsClient
          mkdir -p $out/Applications/EmacsClient.app/Contents/Resources
          cp $out/Applications/Emacs.app/Contents/Resources/Emacs.icns $out/Applications/EmacsClient.app/Contents/Resources/Emacs.icns
          cat << EOF > $out/Applications/EmacsClient.app/Contents/Info.plist
          ${info}
          EOF
        '')
      ];
  })
