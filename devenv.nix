# trigger devenv-test (demonstrating pre-existing failure)
{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; config.allowUnfree = true; };
  # google-chrome has no aarch64-linux build; fall back to chromium there.
  chromeBrowser =
    if pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64
    then pkgs-unstable.chromium
    else pkgs-unstable.google-chrome;
  chromeBinary =
    if pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64
    then "${chromeBrowser}/bin/chromium"
    else "${chromeBrowser}/bin/google-chrome-stable";
in
{
  packages = with pkgs; [
    aws-iam-authenticator
    aws-vault
    awscli
    detect-secrets
    git
    gnumake
    jq
    libyaml
    openssl
    pkgs-unstable.chromedriver
    chromeBrowser
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
    NIX_GOOGLE_CHROME = chromeBinary;
  };

  git-hooks.hooks = {
    detect-secrets = {
      enable = true;
      name = "detect-secrets";
      description = "Detects high entropy strings that are likely to be passwords.";
      entry = "detect-secrets-hook";
      language = "python";
      args = [
        "--baseline"
        ".secrets.baseline"
      ];
    };
  };
}
