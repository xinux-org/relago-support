{
  description = "Xinux support portal";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
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

      perSystem = {
        system,
        pkgs,
        ...
      }: let
        hpkgs = pkgs.haskell.packages."ghc912".override {
          overrides = self: super: {
            bz2 = hlib.dontCheck (hlib.doJailbreak super.bz2);
            bzlib-conduit = hlib.dontCheck (hlib.doJailbreak super.bzlib-conduit);
            bindings-gpgme = hlib.dontCheck (hlib.doJailbreak (self.callCabal2nix "bindings-gpgme"
              ((fetchGit {
                  url = "git@github.com:lambdajon/bindings-dsl.git";
                  ref = "relago";
                  rev = "99d0a65a1479dc14d923c5bc0c93071a923690dc";
                })
                + "/bindings-gpgme")
              {}));

            h-gpgme = hlib.dontCheck (hlib.doJailbreak (self.callCabal2nix "h-gpgme"
              (fetchGit {
                url = "git@github.com:lambdajon/h-gpgme.git";
                ref = "relago";
                rev = "3d8179db81e867280f0f633d4eb280710f3aea92";
              })
              {inherit (self) bindings-gpgme;}));
          };
        };
        hlib = pkgs.haskell.lib;

        defaultShell = pkgs.callPackage ./shell.nix {inherit pkgs;};
        serverShell = pkgs.callPackage ./server/shell.nix {inherit pkgs hpkgs hlib;};
        clientShell = pkgs.callPackage ./client/shell.nix {inherit pkgs;};

        serverPkg = pkgs.callPackage ./server/package.nix {inherit pkgs hpkgs hlib;};
        # clientPkg = pkgs.callPackage ./client/package.nix {inherit pkgs;};
      in {
        devShells.default = defaultShell;

        devShells."server" = defaultShell // serverShell;
        devShells."client" = defaultShell // clientShell;

        packages."server" = serverPkg;
        # packages."client" = clientPkg;
      };
    };
}
