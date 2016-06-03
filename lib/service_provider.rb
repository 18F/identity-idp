class ServiceProvider
  # currently acceptable encryption values are 'none' and 'aes256-cbc'
  DEFAULT_ENCRYPTION = 'none'.freeze

  def initialize(host)
    @host = host
  end

  def metadata
    ignored_methods = [:fingerprint_cert, :metadata, :invalid?, :test_fingerprint]
    metadata_methods = self.class.instance_methods(false) - ignored_methods

    @metadata ||= metadata_methods.inject({}) do |hash, method|
      hash.merge(:"#{method}" => send(method))
    end
  end

  def acs_url
    host_attributes['acs_url']
  end

  def assertion_consumer_logout_service_url
    host_attributes['assertion_consumer_logout_service_url']
  end

  def sp_initiated_login_url
    host_attributes['sp_initiated_login_url']
  end

  def metadata_url
    host_attributes['metadata_url']
  end

  def cert
    return if host_attributes['cert'].blank?

    cert_dir = "#{Rails.root}/certs/sp/"

    @cert ||= File.read("#{cert_dir}#{host_attributes['cert']}.crt")
  end

  def encrypt_responses?
    block_encryption != 'none'
  end

  def block_encryption
    host_attributes['block_encryption'] || DEFAULT_ENCRYPTION
  end

  def key_transport
    'rsa-oaep-mgf1p'
  end

  def encryption_opts
    return nil unless encrypt_responses?
    {
      cert: OpenSSL::X509::Certificate.new(cert),
      block_encryption: block_encryption,
      key_transport: key_transport
    }
  end

  def fingerprint
    return test_fingerprint if Rails.env.test?
    @fingerprint ||= fingerprint_cert(cert)
  end

  def double_quote_xml_attribute_values
    true
  end

  private

  def fingerprint_cert(cert_pem)
    return nil unless cert_pem
    cert = OpenSSL::X509::Certificate.new(cert_pem)
    OpenSSL::Digest::SHA256.new(cert.to_der).hexdigest
  end

  def test_fingerprint
    '40:80:8E:52:EF:80:F9:2E:69:71:49:E0:58:AF:95:F8:98:CE:FD:9A:54:D0:DC:24:16:BD:60:7C:8F:98:91:FA'
  end

  def config
    @config ||= YAML.load_file("#{Rails.root}/config/service_providers.yml")

    if Figaro.env.domain_name == 'superb.legit.domain.gov'
      @config.merge!(@config.fetch('superb.legit.domain.gov', {}))
    else
      @config.merge!(@config.fetch(Rails.env, {}))
    end

    @config.symbolize_keys!
  end

  def host_attributes
    config[:valid_hosts].fetch(@host, {})
  end
end
