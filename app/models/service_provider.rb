require 'fingerprinter'

class ServiceProvider < ApplicationRecord
  scope(:active, -> { where(active: true) })

  def self.from_issuer(issuer)
    find_by(issuer: issuer) || NullServiceProvider.new(issuer: issuer)
  end

  def metadata
    attributes.symbolize_keys.merge(fingerprint: fingerprint)
  end

  def ssl_cert
    @ssl_cert ||= begin
      return if cert.blank?

      cert_file = Rails.root.join('certs', 'sp', "#{cert}.crt")

      return OpenSSL::X509::Certificate.new(cert) unless File.exist?(cert_file)

      OpenSSL::X509::Certificate.new(File.read(cert_file))
    end
  end

  def fingerprint
    @_fingerprint ||= super || Fingerprinter.fingerprint_cert(ssl_cert)
  end

  def encrypt_responses?
    block_encryption != 'none'
  end

  def encryption_opts
    return nil unless encrypt_responses?
    {
      cert: ssl_cert,
      block_encryption: block_encryption,
      key_transport: 'rsa-oaep-mgf1p',
    }
  end

  def live?
    active? && approved?
  end
end
