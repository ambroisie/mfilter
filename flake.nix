{
  description = "A maildir filtering program";

  inputs = {
    flake-utils = {
      type = "github";
      owner = "numtide";
      repo = "flake-utils";
      ref = "master";
    };

    naersk = {
      type = "github";
      owner = "nix-community";
      repo = "naersk";
      ref = "master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixpkgs-unstable";
    };

    pre-commit-hooks = {
      type = "github";
      owner = "cachix";
      repo = "pre-commit-hooks.nix";
      ref = "master";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };

    rust-overlay = {
      type = "github";
      owner = "oxalica";
      repo = "rust-overlay";
      ref = "master";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    { self
    , flake-utils
    , naersk
    , nixpkgs
    , pre-commit-hooks
    , rust-overlay
    }:
    {
      overlay = final: prev: {
        mfilter =
          let
            inherit (final) system;
            overlays = [
              (import rust-overlay)
            ];
            pkgs = import nixpkgs { inherit overlays system; };
            my-rust = pkgs.rust-bin.stable.latest;
            naersk-lib = naersk.lib."${system}".override {
              cargo = my-rust.default;
              rustc = my-rust.default;
            };
          in
          naersk-lib.buildPackage {
            pname = "mfilter";

            src = ./.;

            passthru = {
              inherit my-rust;
            };

            meta = with final.lib; {
              homepage = "https://gitea.belanyi.fr/ambroisie/mfilter";
              license = with licenses; [ mit asl20 ];
              maintainers = with maintainers; [ ambroisie ];
              platforms = platforms.unix;
            };
          };
      };
    } // (flake-utils.lib.eachDefaultSystem (system:
    let
      overlays = [ self.overlay ];
      pkgs = import nixpkgs { inherit overlays system; };
      inherit (pkgs) lib;
      inherit (pkgs.mfilter.passthru) my-rust;
    in
    rec {
      apps = {
        mfilter = flake-utils.lib.mkApp { drv = packages.mfilter; };
      };

      checks = {
        pre-commit = pre-commit-hooks.lib.${system}.run {
          src = ./.;

          # FIXME: clippy and rustfmt fail when inside `nix flake check`
          # but `pre-commit run --all` works properly...
          # Also a problem when not overriding the `entry`
          hooks = {
            clippy = {
              enable = true;
              entry = lib.mkForce "${my-rust.clippy}/bin/cargo-clippy clippy";
            };

            nixpkgs-fmt = {
              enable = true;
            };

            rustfmt = {
              enable = true;
              entry = lib.mkForce "${my-rust.rustfmt}/bin/cargo-fmt fmt -- --check --color always";
            };
          };
        };
      };

      defaultApp = apps.mfilter;

      defaultPackage = packages.mfilter;

      devShell = pkgs.mkShell {
        inputsFrom = [
          defaultPackage
        ];

        nativeBuildInputs = with pkgs; [
          rust-analyzer
        ];

        inherit (checks.pre-commit) shellHook;

        RUST_SRC_PATH = "${my-rust.rust-src}/lib/rustlib/src/rust/library";
      };

      packages = {
        inherit (pkgs) mfilter;
      };
    }));
}
