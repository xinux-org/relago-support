{
  description = "Xinux support portal";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      flake = {
        nixosModules = {
          # client = import ./client/module.nix self;
          server = import ./server/module.nix self;
        };
      };

      perSystem =
        {
          system,
          pkgs,
          ...
        }:
        let
          hpkgs = pkgs.haskell.packages."ghc912".override {
            overrides = self: super: {
              bz2 = hlib.dontCheck (hlib.doJailbreak super.bz2);
              bzlib-conduit = hlib.dontCheck (hlib.doJailbreak super.bzlib-conduit);

              resolv = hlib.overrideCabal super.resolv (drv: {
                configureFlags = (drv.configureFlags or [ ]) ++ [
                  "--ghc-option=+RTS"
                  "--ghc-option=-K128M"
                  "--ghc-option=-RTS"
                ];
              });
            };
          };
          hlib = pkgs.haskell.lib;

          defaultShell = pkgs.callPackage ./shell.nix { inherit pkgs; };
          serverShell = pkgs.callPackage ./server/shell.nix { inherit pkgs hpkgs hlib; };
          clientShell = pkgs.callPackage ./client/shell.nix { inherit pkgs; };

          serverPkg = pkgs.callPackage ./server/package.nix { inherit pkgs hpkgs hlib; };
          # clientPkg = pkgs.callPackage ./client/pnix {inherit pkgs;};
        in
        {
          devShells.default = defaultShell;

          devShells."server" = defaultShell // serverShell;
          devShells."client" = defaultShell // clientShell;

          packages."server" = serverPkg;
          # packages."client" = clientPkg;
        };
    };
}
