{
  pkgs ? import <nixpkgs>,
  hpkgs,
  hlib,
  ...
}:
pkgs.haskell.lib.overrideCabal (hpkgs.callPackage ./relago-server.nix { }) (_: {
  doCheck = true;
  doHaddock = false;
  enableLibraryProfiling = false;
  enableExecutableProfiling = false;
})
