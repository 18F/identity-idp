require 'fingerprinter'

class ServiceProvider
  attr_reader :issuer

  def initialize(issuer)
    @issuer = issuer
  end

  def metadata
    sp_attributes.merge!(fingerprint: fingerprint)
  end

  def encryption_opts
    return nil unless encrypt_responses?
    {
      cert: ssl_cert,
      block_encryption: block_encryption,
      key_transport: 'rsa-oaep-mgf1p'
    }
  end

  def valid?
    VALID_SERVICE_PROVIDERS.include?(issuer)
  end

  def ssl_cert
    @ssl_cert ||= begin
      sp_cert = sp_attributes[:cert]
      return if sp_cert.blank?

      cert_file = File.read(Rails.root.join("certs/sp/#{sp_cert}.crt"))
      OpenSSL::X509::Certificate.new(cert_file)
    end
  end

  private

  def sp_attributes
    @sp_attributes ||= config.sp_attributes
  end

  def config
    ServiceProviderConfig.new(issuer: issuer)
  end

  def fingerprint
    @fingerprint ||= Fingerprinter.fingerprint_cert(ssl_cert)
  end

  def encrypt_responses?
    block_encryption != 'none'
  end

  def block_encryption
    sp_attributes[:block_encryption]
  end
end
