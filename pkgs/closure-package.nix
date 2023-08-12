{ fromPath
, fromStore ? "https://cache.nixos.org"
, inputAddressed ? true
, ... } @ args:

(
  builtins.removeAttrs args [
    "fromPath"
    "fromStore"
  ]
) // {
  outPath = builtins.fetchClosure {
    /* need experimental nix:
      - after: https://github.com/NixOS/nix/pull/8370
      - static build: https://hydra.nixos.org/build/229213111

      nix profile install \
        /nix/store/ik8hqwxhj1q9blqf47rp76h7gw7s3060-nix-2.17.1-x86_64-unknown-linux-musl

      - /etc/nix/nix.conf: extra-experimental-features = fetch-closure
      - systemctl restart nix-daemon.service
    */
    inherit
      fromPath
      fromStore
      inputAddressed;
  };
}