{pkgs}:
pkgs.mkShell {
  name = "relago-support-shell";

  packages = with pkgs; [
    nixd
    statix
    deadnix
    alejandra
    treefmt
  ];

  NIX_CONFIG = "extra-experimental-features = nix-command flakes";
}
