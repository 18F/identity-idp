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
    terragrunt
    git
    jq
    postgresql
    zlib
    libyaml
    openssl_1_1
    pkgs-unstable.chromedriver
  ];

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/languages/
  languages.nix.enable = true;

  # temporary workaround
  # https://github.com/cachix/devenv/issues/792
  # NIXPKGS_ALLOW_INSECURE=1 nix run --impure github:bobvanderlinden/nixpkgs-ruby\#'"ruby-3.0.5"'
  # may also require this
  # NIXPKGS_ALLOW_INSECURE=1 nix run --impure "nixpkgs#openssl_1_1"
  # nix run "nixpkgs#clang_16"

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

  languages.terraform = {
    enable = true;
    # version = "1.10.5";
    version = "1.11.0";
  };

  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
  };

  services.redis = {
    enable = true;
  };
  
  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

}
