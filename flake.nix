{
  description = "Development environment for fomome-staking";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/68c9ed8bbed9dfce253cc91560bf9043297ef2fe";
    flake-utils.url = "github:numtide/flake-utils/b1d9ab70662946ef0850d488da1c9019f3a9752a";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs
            nodePackages.npm
            pnpm
          ];
        };
      }
    );
}