require 'fingerprinter'
require 'identity_validations'

class ServiceProvider < ApplicationRecord
  self.ignored_columns = %w[deal_id agency aal fingerprint cert]

  belongs_to :agency

  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :identities, inverse_of: :service_provider_record,
                        foreign_key: 'service_provider',
                        primary_key: 'issuer',
                        class_name: 'ServiceProviderIdentity'
  # rubocop:enable Rails/HasManyOrHasOneDependent

  # Do not define validations in this model.
  # See https://github.com/18F/identity_validations
  include IdentityValidations::ServiceProviderValidation

  scope(:active, -> { where(active: true) })
  scope(:with_push_notification_urls,
        -> { where.not(push_notification_url: nil).where.not(push_notification_url: '') })

  def self.from_issuer(issuer)
    return NullServiceProvider.new(issuer: nil) if issuer.blank? || issuer.include?("\x00")
    find_by(issuer: issuer) || NullServiceProvider.new(issuer: issuer)
  end

  def metadata
    attributes.symbolize_keys
  end

  # @return [Array<OpenSSL::X509::Certificate>]
  def ssl_certs
    @ssl_certs ||= Array(certs).map do |cert|
      OpenSSL::X509::Certificate.new(load_cert(cert))
    end
  end

  def encrypt_responses?
    block_encryption != 'none'
  end

  def skip_encryption_allowed
    config = IdentityConfig.store.skip_encryption_allowed_list
    return false if config.blank?

    @allowed_list ||= config
    @allowed_list.include? issuer
  end

  def live?
    active? && approved?
  end

  private

  def load_cert(cert)
    cert_file = Rails.root.join('certs', 'sp', "#{cert}.crt")
    return OpenSSL::X509::Certificate.new(cert) unless File.exist?(cert_file)
    File.read(cert_file)
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
