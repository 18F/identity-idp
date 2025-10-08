{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
in
{
  packages = with pkgs; [
    aws-iam-authenticator
    aws-vault
    awscli
    git
    gnumake
    jq
    libyaml
    openssl
    pkgs-unstable.chromedriver
    ssm-session-manager-plugin
    yubikey-manager
    zlib
  ];

  languages = {
    ruby = {
      enable = true;
      bundler.enable = true;
      versionFile = ./.ruby-version;
    };
    javascript = {
      enable = true;
      package = pkgs-unstable.nodejs-slim;
      npm.enable = true;
    };
  };

  enterShell = ''
    # Conflicts with bundler
    export RUBYLIB=
  '';

  tasks = {
    "ruby:install_gems" = {
      exec = "bundle install";
      status = "bundle check";
      before = [ "devenv:enterShell" ];
    };
  };

  services = {
    postgres = {
      enable = true;
      package = pkgs.postgresql_16;
      listen_addresses = "127.0.0.1";
    };
    redis = {
      enable = true;
    };
  };

  dotenv.enable = true;

  env = {
    AWS_VAULT_KEYCHAIN_NAME = "login";
    AWS_VAULT_PROMPT = "ykman";
  };
}
