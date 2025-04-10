{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
in
{
  # https://devenv.sh/packages/
  packages = with pkgs; [ 
    aws-vault
    awscli
    ssm-session-manager-plugin
    aws-iam-authenticator
    yubikey-manager
    git
    jq
    postgresql
    zlib
    libyaml
    openssl_1_1
    pkgs-unstable.chromedriver
  ];

  cachix.enable = false;
  
  languages.ruby = {
    enable = true;
    bundler.enable = true;
    versionFile = ./.ruby-version;
  };

  languages.javascript = {
    enable = true;
    package = pkgs-unstable.nodejs-slim;
    yarn.enable = true;
  };

  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
  };

  services.redis = {
    enable = true;
  };
}
