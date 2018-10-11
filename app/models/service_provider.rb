require 'fingerprinter'

class ServiceProvider < ApplicationRecord
  scope(:active, -> { where(active: true) })

  validate :redirect_uris_are_parsable

  def self.from_issuer(issuer)
    return NullServiceProvider.new(issuer: nil) if issuer.blank?
    find_by(issuer: issuer) || NullServiceProvider.new(issuer: issuer)
  end

  def metadata
    attributes.symbolize_keys.merge(fingerprint: fingerprint)
  end

  def ssl_cert
    @ssl_cert ||= begin
      return if cert.blank?
      OpenSSL::X509::Certificate.new(load_cert(cert))
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

  def piv_cac_available?(user = nil)
    PivCacService.piv_cac_available_for_agency?(agency, user&.email_address&.email)
  end

  private

  def load_cert(cert)
    if RemoteSettingsService.remote?(cert)
      RemoteSettingsService.load(cert)
    else
      cert_file = Rails.root.join('certs', 'sp', "#{cert}.crt")
      return OpenSSL::X509::Certificate.new(cert) unless File.exist?(cert_file)
      File.read(cert_file)
    end
  end

  def redirect_uris_are_parsable
    return if redirect_uris.blank?

    redirect_uris.each do |uri|
      next if redirect_uri_valid?(uri)
      errors.add(:redirect_uris, :invalid)
      break
    end
  end

  def redirect_uri_valid?(redirect_uri)
    parsed_uri = URI.parse(redirect_uri)
    parsed_uri.scheme.present? && parsed_uri.host.present?
  rescue URI::BadURIError, URI::InvalidURIError
    false
  end
end
