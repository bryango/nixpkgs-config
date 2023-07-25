{
  description = "nixpkgs with personalized config";

  inputs = {

    nixpkgs.url = "nixpkgs";  ## flake registry: nixpkgs/nixpkgs-unstable
 
    /* alternatively,
      - use `master`, which is slightly more advanced;
      - pin to hash, e.g. "nixpkgs/a3a3dda3bacf61e8a39258a0ed9c924eeca8e293";
        ^ note that this is once problematic, but I cannot reproduce
        ^ find nice snapshots from hydra builds:
          https://hydra.nixos.org/jobset/nixpkgs/trunk/evals
    */

    ## python2 marked insecure: https://github.com/NixOS/nixpkgs/pull/201859
    nixpkgs_python2 = {
      ## ... pin to a cached build:
      url = "github:NixOS/nixpkgs/27bd67e55fe09f9d68c77ff151c3e44c4f81f7de";
      follows = "nixpkgs";
      ## ^ toggle to follow `nixpkgs`
    };

    ## nix static: https://hydra.nixos.org/build/229213111
    nix.url = "github:NixOS/nix/07d1e304b4e608bd33ae6ff7ff1760adab7385a4";

  };

  outputs = { self, nixpkgs, ... } @ inputs:
  let

    lib = nixpkgs.lib;
    mySystems = [ "x86_64-linux" ];
    forMySystems = lib.genAttrs mySystems;

    config = {
      ## https://github.com/nix-community/home-manager/issues/2954
      ## ... home-manager/issues/2942#issuecomment-1378627909
      allowBroken = true;
      allowUnfree = true;

      permittedInsecurePackages = [
        "python-2.7.18.6"
        "python-2.7.18.6-env"
      ];
    };

    genOverlay = system:
    let

      pkgs_python2 = import inputs.nixpkgs_python2 {
        inherit system config;
      };

      pkgs_biber217 = import inputs.nixpkgs_biber217 {
        inherit system config;
      };

    in final: prev: let

      inherit (prev)
        callPackage
        recurseIntoAttrs;

      hostSymlinks = recurseIntoAttrs (callPackage ./pkgs/host-links.nix {});

      collectFlakeInputs = name: flake: {
        ${name} = flake;
      } // lib.concatMapAttrs collectFlakeInputs (flake.inputs or {});
      ## https://github.com/NixOS/nix/issues/3995#issuecomment-1537108310

    in { ## be careful of `rec`, might not work

      ## nix static
      nix = inputs.nix.packages.${system}.nix-static;

      inherit collectFlakeInputs;
      flakeInputs = collectFlakeInputs "nixpkgs-config" self;

      ## exec "$name" from system "$PATH"
      ## if not found, fall back to "$package/bin/$name"
      binaryFallback = name: package: callPackage ./pkgs/binary-fallback {
          inherit name package;
        };

      ## create "bin/$name" from a template
      ## with `pkgs.substituteAll attrset`
      binarySubstitute = name: attrset: prev.writeScriptBin name (
        builtins.readFile (prev.substituteAll attrset)
      );

      ## some helper functions
      nixpkgs-helpers = callPackage ./pkgs/nixpkgs-helpers {};

      gimp = prev.gimp.override {
        withPython = true;
        python2 = pkgs_python2.python2;
      };

      tectonic-with-biber = callPackage ./pkgs/tectonic-with-biber.nix {
          biber = pkgs_biber217.biber;
        };

      fcitx5-configtool =
        prev.libsForQt5.callPackage ./pkgs/fcitx5-configtool.nix {
          kcmSupport = false;
        };

      byobu-with-tmux = callPackage (
        { byobu, tmux, symlinkJoin, emptyDirectory }:
        symlinkJoin {
          name = "byobu-with-tmux-${byobu.version}";
          paths = [
            tmux
            (byobu.override {
              textual-window-manager = tmux;
              screen = emptyDirectory;
              vim = emptyDirectory;
            })
          ];
          inherit (byobu) meta;
        }
      ) {};

      ## links to host libraries
      inherit hostSymlinks;
      inherit (hostSymlinks)
        host-usr
        host-locales;

      ## exposes nixpkgs source, i.e. `outPath`, in `pkgs`
      inherit (nixpkgs) outPath;

      ## helper function to gather overlaid packages, defined below
      inherit gatherOverlaid;

    };

    gatherOverlaid = system: final: prev: let

      overlaid = genOverlay system final prev;
      derivable = lib.filterAttrs (name: lib.isDerivation) overlaid;

      userOverlaid = "user-overlaid";
      inherit (prev) linkFarm;

    in {
      ${userOverlaid} = linkFarm userOverlaid derivable;
    };

  in {

    overlays = forMySystems genOverlay;

    legacyPackages = forMySystems (system: import nixpkgs {
      inherit system config;
      overlays = [
        (genOverlay system)
        (gatherOverlaid system)
      ];
    });

    lib = lib.recursiveUpdate lib {
      systems.flakeExposed = mySystems;
      inherit
        mySystems
        forMySystems;
    };

  };
}
