{
  description = "Filetracker caching file storage";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }: {
    overlays.default = final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (python-final: python-prev: {
          filetracker = prev.callPackage ./nix/package.nix python-prev;
        })
      ];

      filetracker = with final.python38Packages; toPythonApplication filetracker;
    };

    nixosModules.default = ./nix/module;
    nixosConfigurations.container = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        (_: {
          nixpkgs.overlays = [
            self.outputs.overlays.default
          ];
        })
        ./nix/container.nix
      ];
    };
  } // (flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
    let
      pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
    in
    {
      packages.default = pkgs.filetracker;
      devShell = pkgs.filetracker;
    }));
}
