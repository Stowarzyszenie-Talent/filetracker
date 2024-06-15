{
  description = "Filetracker caching file storage";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    let
      importWithPin = file:
        ({ pkgs, lib, config, ... }: import file {
          # Use pinned nixpkgs from our input for epic reproducibility.
          pkgs = import nixpkgs {
            inherit (pkgs) system; overlays = [ self.overlays.default ];
          };
          inherit lib config;
        });
    in
    {
      overlays.default = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (python-final: python-prev: {
            filetracker = prev.callPackage ./nix/package.nix python-prev;
          })
        ];

        filetracker = with final.python311Packages; toPythonApplication filetracker;
      };

      nixosModules.default = {
        nixpkgs.overlays = [ self.overlays.default ];
        imports = [
          (importWithPin ./nix/module/cache.nix)
          (importWithPin ./nix/module/server.nix)
        ];
      };

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
