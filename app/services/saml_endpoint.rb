class SamlEndpoint
  attr_reader :year

  def initialize(year)
    @year = year
  end

  def self.suffixes
    endpoint_configs.pluck(:suffix)
  end

  def self.endpoint_configs
    @endpoint_configs ||= IdentityConfig.store.saml_endpoint_configs
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
    if IdentityConfig.store.include_slo_in_saml_metadata
      config.single_logout_service_post_location += year
      config.remote_logout_service_post_location += year
    else
      config.single_logout_service_post_location = nil
      config.remote_logout_service_post_location = nil
    end

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
