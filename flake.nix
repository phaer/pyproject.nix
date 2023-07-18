{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, nix-github-actions }:
    let
      inherit (nixpkgs) lib;
    in
    {
      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks = { inherit (self.checks) x86_64-linux; };
      };

      lib = builtins.removeAttrs (import ./lib { inherit lib; }) [ "tests" ];

    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        pythonEnv =
          let
            pyproject = lib.importTOML ./pyproject.toml;
            parsedDevDeps = map self.lib.pep508.parseString pyproject.tool.pdm.dev-dependencies.dev;
          in
          pkgs.python3.withPackages (ps: map (dep: ps.${dep.name}) parsedDevDeps);
      in
      {

        devShells.default =
          let
            checkInputs = builtins.filter (pkg: pkg != pkgs.nix) (
              lib.unique (lib.flatten (
                lib.mapAttrsToList (_: drv: drv.nativeBuildInputs) self.checks.${system}
              ))
            );
          in
          pkgs.mkShell {
            packages = checkInputs ++ [
              pkgs.pdm
            ];
          };

        checks =
          let
            mkCheck = name: check: pkgs.runCommand name
              (check.attrs or { })
              ''
                cp -rv ${self} src
                chmod +w -R src
                cd src

                ${check.check}

                touch $out
              '';
          in
          lib.mapAttrs mkCheck {
            pytest = {
              attrs = {
                nativeBuildInputs = [
                  pkgs.nix
                  pythonEnv
                ];
                env.NIX_PATH = "nixpkgs=${nixpkgs}";
              };
              check = ''
                export NIX_REMOTE=local?root=$PWD
                pytest --workers auto
              '';
            };

            # Format all the things in one go
            treefmt = {
              attrs.nativeBuildInputs = [ pkgs.treefmt pkgs.nixpkgs-fmt pythonEnv ];
              check = "treefmt --no-cache --fail-on-change";
            };

            # Check for dead Nix code
            deadnix = {
              attrs.nativeBuildInputs = [ pkgs.deadnix ];
              check = "deadnix --fail";
            };

            # Static Nix analysis
            statix = {
              attrs.nativeBuildInputs = [ pkgs.statix ];
              check = "statix check";
            };

            # Python type checking
            mypy = {
              attrs.nativeBuildInputs = [ pythonEnv ];
              check = "mypy .";
            };

            # Python linter
            ruff = {
              attrs.nativeBuildInputs = [ pkgs.ruff ];
              check = "ruff check .";
            };
          };

      });
}
