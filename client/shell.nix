{
  pkgs ? let
    lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
    nixpkgs = fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
      sha256 = lock.narHash;
    };
  in
    import nixpkgs {overlays = [];},
}:
pkgs.mkShell {
  packages = with pkgs; [
    nodejs_20
    pnpm_10
    eslint

    nodePackages.typescript
    nodePackages.typescript-language-server

    nodePackages.prettier
    nodePackages.eslint
  ];

  shellHook = ''
    echo "React + TypeScript + Vite development environment"
    echo "Node version: $(node --version)"
    echo "pnpm version: $(pnpm --version)"
    echo ""
  '';

  PNPM_HOME = "${toString ./.}/.pnpm-store";
}
