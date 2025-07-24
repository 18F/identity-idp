{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = with pkgs; [
    aws-iam-authenticator
    aws-vault
    awscli
    chromedriver
    git
    gnumake
    jq
    libyaml
    openssl
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
      yarn.enable = true;
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
}
