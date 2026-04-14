{
  pkgs ? import <nixpkgs>,
  hpkgs,
  hlib,
  ...
}:
let
  generated = (hpkgs.callPackage ./relago-server.nix { });
in
pkgs.haskell.lib.overrideCabal generated (_: {
  doCheck = true;
  doHaddock = false;
  enableLibraryProfiling = false;
  enableExecutableProfiling = false;
})
