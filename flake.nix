{
  description = "DevShell for identity-idp";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:

    flake-utils.lib.eachDefaultSystem (
      system:

      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShell =
          with pkgs;

          mkShell {
            buildInputs = [
              ruby
              yarn
              openssl.dev
              postgresql.dev
              libyaml.dev
              zlib.dev
              goreman # Use goreman since nginx launch will fail gracefully and launch Puma, as opposed to when using foreman
            ];

            shellHook = ''
              export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.postgresql.dev}/lib/pkgconfig:${pkgs.libyaml.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig:$PKG_CONFIG_PATH";
            '';
          };
      }
    );
}
