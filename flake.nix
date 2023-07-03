{
  description = "Entropy bot in zig";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

        buildInputs = with pkgs; [
          zig
          valgrind
        ];
      in
      rec {
        # `nix build`
        packages = {
          chess-zig = pkgs.stdenv.mkDerivation {
            inherit buildInputs;
            name = "BoltzmannBrain";
            src = self;

            installPhase = ''
              zig build
            '';
          };
        };
        defaultPackage = packages.chess-zig;

        # `nix run`
        apps.chess-zig = utils.lib.mkApp {
          drv = packages.chess-zig;
        };
        defaultApp = apps.chess-zig;

        # `nix develop`
        devShell = pkgs.mkShell {
          inherit buildInputs;
        };
      });
}
