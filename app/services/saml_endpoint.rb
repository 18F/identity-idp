class SamlEndpoint
  attr_reader :request

  def initialize(request)
    @request = request
  end

  def self.suffixes
    endpoint_configs.map { |config| config[:suffix] }
  end

  def self.endpoint_configs
    @endpoint_configs ||= IdentityConfig.store.saml_endpoint_configs
  end

  def secret_key
    key_contents = begin
      AppArtifacts.store["saml_#{suffix}_key"]
    rescue NameError
      raise "No SAML private key for suffix #{suffix}"
    end

    OpenSSL::PKey::RSA.new(
      key_contents,
      endpoint_config[:secret_key_passphrase],
    )
  end

  def x509_certificate
    AppArtifacts.store["saml_#{suffix}_cert"]
  rescue NameError
    raise "No SAML certificate for suffix #{suffix}"
  end

  def saml_metadata
    config = SamlIdp.config.dup
    config.single_service_post_location = config.single_service_post_location + suffix
    config.single_logout_service_post_location = config.single_logout_service_post_location + suffix
    SamlIdp::MetadataBuilder.new(
      config,
      x509_certificate,
      secret_key,
    )
  end

  private

  def endpoint_config
    @endpoint_config ||= self.class.endpoint_configs.find do |config|
      config[:suffix] == suffix
    end
  end

  def suffix
    @suffix ||= begin
      suffixes = self.class.endpoint_configs.map { |config| config[:suffix] }
      suffixes.find do |suffix|
        request.path.match(/(metadata|auth(post)?|logout)#{suffix}$/)
      end
    end
  end
end
