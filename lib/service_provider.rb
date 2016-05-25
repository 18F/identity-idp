class ServiceProvider
  def self.domain_endpoints
    providers = YAML.load_file("#{Rails.root}/config/service_providers.yml")
    providers = providers.fetch(Rails.env, {})
    providers.symbolize_keys!

    provider_attributes = providers[:valid_hosts].values

    acs_urls = provider_attributes.map { |hash| hash['acs_url'] }

    whitelisted_domains = acs_urls.map do |url|
      host = URI.parse(url).host.downcase
    end
    whitelisted_domains.uniq
  end

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

    cert_dir = "#{Rails.root}/certs/"

    @cert ||= File.read("#{cert_dir}#{host_attributes['cert']}.crt")
  end

  def block_encryption
    host_attributes['block_encryption']
  end

  def key_transport
    'rsa-oaep-mgf1p'
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
    'F9:A3:9B:2F:8F:1C:E2:79:27:69:EB:32:ED:2A:D5:A2:A7:58:5F:C0:74:8A:4A:03' \
    ':D9:0F:77:A5:89:7F:F9:68'
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
