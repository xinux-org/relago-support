{
  pkgs,
  hpkgs,
  hlib,
  ...
}:
pkgs.haskell.lib.overrideCabal (hpkgs.callCabal2nix "relago-server" ./. {}) (_: {
  doCheck = true;
  doHaddock = false;
  enableLibraryProfiling = false;
  enableExecutableProfiling = false;
})
