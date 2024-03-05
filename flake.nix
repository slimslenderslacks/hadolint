{
  description = "hadolint";
  inputs.haskellNix.url = "github:input-output-hk/haskell.nix";
  inputs.nixpkgs.follows = "haskellNix/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, haskellNix }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system:
      let

        staticFlags = { pkgs }: [
          "--disable-executable-dynamic"
          "--disable-shared"
          "--ghc-option=-optl=-pthread"
          "--ghc-option=-optl=-static"
          "--ghc-option=-optl=-L${pkgs.gmp6.override { withStatic = true; }}/lib"
          "--ghc-option=-optl=-L${pkgs.glibc.static}/lib"
        ];

        hsApp = { hNix, configureFlags }:
          hNix // {
            hadolint = hNix.hadolint // {
              components = hNix.hadolint.components // {
                exes = hNix.hadolint.components.exes // {
                  hadolint = hNix.hadolint.components.exes.hadolint // {
                    dontStrip = false;
                    dontPatchElf = false;
                    configureFlags = configureFlags;
                  };
                };
              };
            };
          };

        overlays = [
          haskellNix.overlay
          (final: prev:
            let
              p =
                final.haskell-nix.project' {
                  src = ./.;
                  compiler-nix-name = "ghc924";
                  # This is used by `nix develop .` to open a shell for use with
                  # `cabal`, `hlint` and `haskell-language-server`
                  shell.tools = {
                    cabal = { };
                    #hlint = {};
                    haskell-language-server = { };
                  };
                  # Non-Haskell shell tools go here
                  shell.buildInputs = with pkgs; [
                    nixpkgs-fmt
                  ];
                  # This adds `js-unknown-ghcjs-cabal` to the shell.
                  # shell.crossPlatforms = p: [p.ghcjs];
                };
              configureFlags =
                if system == "aarch64-darwin"
                then [ ]
                else
                  (staticFlags final);
            in
            {
              project = (hsApp { hNix = p; inherit configureFlags; });
            })
        ];

        #crossSystem =
          #if system == "x86_64-linux" then
            #native.lib.systems.examples.musl64
          #else if system == "aarch64-static" then
            #native.lib.systems.examples.aarch64-multiplatform-musl
          #else
            #native.lib.systems.examples.aarch64-darwin;

        pkgs = import nixpkgs { inherit system overlays; inherit (haskellNix) config; };

        flake = pkgs.project.flake {
          # This adds support for `nix build .#js-unknown-ghcjs:hello:exe:hello`
          # crossPlatforms = p: [p.ghcjs];
        };
      in
      flake // {
        # Built by `nix build .`
        packages.default = flake.packages."hadolint:exe:hadolint";
      });
}
