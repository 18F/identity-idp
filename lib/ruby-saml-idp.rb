# encoding: utf-8
module SamlIdp
  require 'saml-idp/configurator'
  require 'saml-idp/controller'
  require 'saml-idp/default'
  require 'saml-idp/version'
  require 'saml-idp/engine' if defined?(::Rails) && Rails::VERSION::MAJOR > 2

  def self.config=(config)
    @config = config
  end

  def self.config
    @config ||= SamlIdp::Configurator.new
  end

end

