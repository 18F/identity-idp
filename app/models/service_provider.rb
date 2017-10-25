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

  def name_id_format
    # default to persistent if name_id_format_type is nil
    key = name_id_format_type || 'persistent'

    NAME_ID_FORMAT_TYPE_OPTIONS.fetch(key)
  end

  # Mapping of string name_id_format_type String values to the Hash that
  # the saml_idp gem expects to find in order to select a NameID format and
  # NameID getter function, which is called with the principal to get the value
  # to be used for the NameID in SAML messages.
  NAME_ID_FORMAT_TYPE_OPTIONS = {
    'persistent' => {
      name: Saml::XML::Namespaces::Formats::NameId::PERSISTENT,
      getter: proc { |principal|
        principal.asserted_attributes.fetch(:uuid).fetch(:getter).call(principal)
      },
    }.freeze,
    'email' => {
      name: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
      getter: :email,
    }.freeze,
    nil => nil,
  }.freeze

  validates :name_id_format_type, inclusion: { in: NAME_ID_FORMAT_TYPE_OPTIONS }
end
