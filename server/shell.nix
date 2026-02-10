{
  pkgs,
  hpkgs,
  hlib,
  ...
}:
pkgs.mkShell {
  name = "relago-server-dev";

  # Compile time dependencies
  packages = [
    hpkgs.cabal-install
    hpkgs.haskell-language-server
    hpkgs.fourmolu
    hpkgs.hlint
    hpkgs.implicit-hie
    hpkgs.ghcid
    hpkgs.ghc

    pkgs.haskellPackages.cabal-fmt
  ];

  shellHook = ''
    echo "Welcome to development";

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.postgresql}/lib
  '';
  NIX_CONFIG = "extra-experimental-features = nix-command flakes";
}
