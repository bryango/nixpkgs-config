{ closurePackage
, symlinkJoin
, chezmoi
}:

let

  pname = "chezmoi";
  version = assert chezmoi.version == "2.38.0"; "${chezmoi.version}-acb8937";
  executable = closurePackage {
    /*
      musl artifact:
        https://github.com/twpayne/chezmoi/actions/runs/6016856853
      - `nix store add-file`
      - `nix store make-content-addressed`
      - `echo "$storePath" | cachix push chezbryan`
    */
    fromStore = "https://chezbryan.cachix.org";
    fromPath = /nix/store/dnzaicq1q4b6192ad9jhg5gnzakbz9z3-chezmoi;
    toPath = /nix/store/ywfv1wr2pjghniar48f6f2ck8zhx6y1g-chezmoi;
    pname = "${pname}-static";
    inherit version;
  };

in

symlinkJoin {
  inherit pname version;
  inherit (chezmoi) meta;
  name = "${pname}-${version}";
  paths = [ chezmoi ];
  postBuild = ''
    ## replace the executable
    cp -f "${executable}" $out/bin/${pname}
    ## keep everything else (e.g. shell completions)
  '';
}
