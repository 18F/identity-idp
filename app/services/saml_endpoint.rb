class SamlEndpoint
  attr_reader :request

  def initialize(request)
    @request = request
  end

  def self.suffixes
    endpoint_configs.map { |config| config[:suffix] }
  end

  def self.endpoint_configs
    @endpoint_configs ||= JSON.parse(Figaro.env.saml_endpoint_configs, symbolize_names: true)
  end

  def cloudhsm_key_label
    return unless FeatureManagement.use_cloudhsm?
    endpoint_config[:cloudhsm_key_label]
  end

  def secret_key
    filepath = Rails.root.join('keys', "saml#{suffix}.key.enc")
    unless File.exist?(filepath)
      return if cloudhsm_key_label.present?
      raise "No private key at path #{filepath}"
    end
    OpenSSL::PKey::RSA.new(
      File.read(filepath),
      endpoint_config[:secret_key_passphrase],
    )
  end

  def x509_certificate
    @x509_certification ||= begin
      filepath = Rails.root.join(
        'certs',
        "saml#{suffix}.crt",
      )
      File.read(filepath)
    end
  end

  def saml_metadata
    config = SamlIdp.config.dup
    config.single_service_post_location = config.single_service_post_location + suffix
    config.single_logout_service_post_location = config.single_logout_service_post_location + suffix
    SamlIdp::MetadataBuilder.new(
      config,
      x509_certificate,
      secret_key,
      cloudhsm_key_label,
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
        request.path.match(/(metadata|auth|logout)#{suffix}$/)
      end
    end
  end
end
