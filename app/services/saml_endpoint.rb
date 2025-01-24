# frozen_string_literal: true

class SamlEndpoint
  SAML_YEARS = AppArtifacts.store.members.map(&:to_s).map do |key|
    regex = /saml_(?<year>\d{4})_(?<key_cert>key|cert)/
    matches = regex.match(key)
    matches && matches[:year]
  end.compact.uniq.freeze

  attr_reader :year

  def initialize(year)
    @year = year
  end

  def self.valid_year?(year)
    SAML_YEARS.include?(year)
  end

  def self.suffixes
    endpoint_configs.pluck(:suffix)
  end

  def self.endpoint_configs
    IdentityConfig.store.saml_endpoint_configs
  end

  def secret_key
    key_contents = begin
      AppArtifacts.store["saml_#{year}_key"]
    rescue NameError
      raise "No SAML private key for suffix #{year}"
    end

    OpenSSL::PKey::RSA.new(
      key_contents,
      endpoint_config[:secret_key_passphrase],
    )
  end

  def x509_certificate
    AppArtifacts.store["saml_#{year}_cert"]
  rescue NameError
    raise "No SAML certificate for suffix #{year}"
  end

  def saml_metadata
    config = SamlIdp.config.dup
    config.single_service_post_location += year

    SamlIdp::MetadataBuilder.new(
      config,
      x509_certificate,
      secret_key,
    )
  end

  private

  def endpoint_config
    @endpoint_config ||= self.class.endpoint_configs.find do |config|
      config[:suffix] == year
    end
  end
end
