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

      perSystem = {
        system,
        pkgs,
        ...
      }: let
        hpkgs = pkgs.haskell.packages.ghc910;
        hlib = pkgs.haskell.lib;
        defaultShell = pkgs.callPackage ./shell.nix {inherit pkgs;};
        serverShell = pkgs.callPackage ./server/shell.nix {inherit pkgs hpkgs hlib;};
      in {
        devShells.default = defaultShell;

        devShells."server" = defaultShell // serverShell;

        packages."server" = pkgs.callPackage ./server/package.nix {inherit pkgs hpkgs hlib;};

        #FIXME: Need implment fror frontend

        devShells.frontend = pkgs.mkShell {
          shellHook = ''
            echo "Welcome to js"
          '';
        };
      };
    };
}
