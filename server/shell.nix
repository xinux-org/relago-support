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
    hpkgs.cabal-add
    hpkgs.hpack
    hpkgs.bindings-libzip
    hpkgs.bzlib
    hpkgs.bzlib-conduit
    hpkgs.bzip2-clib
    hpkgs.postgresql-libpq
    hpkgs.postgresql-libpq-configure
    # hpkgs.bzip2-clib

    pkgs.haskellPackages.cabal-fmt

    pkgs.zlib
    pkgs.zlib.dev
    pkgs.libz
    pkgs.pkg-config
    pkgs.xz
    pkgs.bzip2
    pkgs.libzip
    pkgs.gpgme
    pkgs.libpq.pg_config
    pkgs.libpq.dev

    # pkgs.lbzip2
    # pkgs.bzip3
    # pre-commit-check.enabledPackages
  ];

  shellHook = ''
    echo "Welcome to development";

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.postgresql}/lib
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.libzip}/lib
    # export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.bzip3}/lib
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.bzip2}/lib
    export LIBRARY_PATH=$LIBRARY_PATH:${pkgs.bzip2}/lib


  '';
  NIX_CONFIG = "extra-experimental-features = nix-command flakes";
}
