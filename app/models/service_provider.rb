# frozen_string_literal: true

require 'fingerprinter'
require 'identity_validations'

class ServiceProvider < ApplicationRecord
  belongs_to :agency

  # rubocop:disable Rails/HasManyOrHasOneDependent
  # In order to preserve unique user UUIDs, we do not want to destroy Identity records
  # when we destroy a ServiceProvider
  has_many :identities, inverse_of: :service_provider_record,
                        foreign_key: 'service_provider',
                        primary_key: 'issuer',
                        class_name: 'ServiceProviderIdentity'
  # rubocop:enable Rails/HasManyOrHasOneDependent
  has_many :in_person_enrollments,
           inverse_of: :service_provider,
           foreign_key: 'issuer',
           primary_key: 'issuer',
           dependent: :destroy

  has_one :integration,
          inverse_of: :service_provider,
          foreign_key: 'issuer',
          primary_key: 'issuer',
          class_name: 'Agreements::Integration',
          dependent: nil

  # The API URLs of this record when it is an application registered for delegated access.
  has_many :token_exchange_resource_servers, inverse_of: :service_provider, dependent: :destroy

  include DelegationLocalizedContent
  # Consent-screen content an agency writes about this application; jsonb keyed by locale.
  localized_content :delegation_display_name, :delegation_description, :delegation_data_provided

  # Prefix every application's delegation scope carries on the wire:
  # `token_exchange:<delegation_scope_value>`.
  DELEGATION_SCOPE_PREFIX = 'token_exchange:'
  DELEGATION_ACCESS_TYPES = %w[read read_write].freeze

  # Do not define validations in this model
  # See https://github.com/18F/identity_validations
  include IdentityValidations::ServiceProviderValidation

  scope(:active, -> { where(active: true) })
  scope(
    :with_push_notification_urls,
    -> {
      where.not(push_notification_url: nil)
        .where.not(push_notification_url: '')
        .where(active: true)
    },
  )

  IAA_INTERNAL = 'LGINTERNAL'

  scope(:internal, -> { where(iaa: IAA_INTERNAL) })
  scope(:external, -> { where.not(iaa: IAA_INTERNAL).or(where(iaa: nil)) })

  def metadata
    attributes.symbolize_keys.merge(certs: ssl_certs)
  end

  # @return [Array<OpenSSL::X509::Certificate>]
  def ssl_certs
    @ssl_certs ||= Array(certs).select(&:present?).map do |cert|
      cert_content = load_cert(cert)
      OpenSSL::X509::Certificate.new(cert_content) if cert_content
    end.compact
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

  def identity_proofing_allowed?
    ial.present? && ial >= 2
  end

  def ialmax_allowed?
    IdentityConfig.store.allowed_ialmax_providers.include?(issuer)
  end

  # Whether this SP is onboarded as a token-exchange broker: login controls the
  # capability via a per-SP allowlist, independent of the broker's own signed
  # target manifest.
  def token_exchange_broker_allowed?
    IdentityConfig.store.token_exchange_enabled &&
      IdentityConfig.store.token_exchange_service_providers.include?(issuer)
  end

  # Whether this record is an application registered for delegated access: an agency-owned
  # record a service provider may act at on the user's behalf, owning one or more API URLs
  # (token_exchange_resource_servers).
  def delegation_application?
    active? && delegation_application
  end

  # The scope value a service provider sends to request this application, with its prefix,
  # e.g. "token_exchange:housing_records". Nil for records that are not applications.
  def delegation_scope
    return nil if delegation_scope_value.blank?

    "#{DELEGATION_SCOPE_PREFIX}#{delegation_scope_value}"
  end

  # Whether this application accepts delegation from the given service provider. The agency
  # lists the service providers it accepts in its own configuration; an empty list means any
  # service provider Login.gov has approved for delegation, so an agency that does not care needs
  # no configuration. A record that is not an application accepts nobody.
  def accepts_delegation_from?(service_provider_issuer)
    return false unless delegation_application?

    allowed = Array(allowed_delegation_service_providers).map(&:to_s)
    allowed.empty? || allowed.include?(service_provider_issuer.to_s)
  end

  def delegation_read_write?
    delegation_access_type == 'read_write'
  end

  def document_images_sharing_allowed?
    IdentityConfig.store.document_images_sharing_enabled &&
      IdentityConfig.store.document_images_sharing_service_providers.include?(issuer)
  end

  def attempts_api_enabled?
    IdentityConfig.store.attempts_api_enabled && attempts_config.present?
  end

  def attempts_public_key
    if attempts_config.present? && attempts_config['keys'].present?
      OpenSSL::PKey::RSA.new(attempts_config['keys'].first)
    else
      ssl_certs.first.public_key
    end
  end

  def create_prompt_allowed?
    IdentityConfig.store.allowed_create_prompt_providers.include?(issuer)
  end

  def logo_url
    LogoUrl.new(logo, remote_logo_key).url
  end

  def logo_is_email_compatible?
    logo_url.end_with?('.png')
  end

  def receives_client_id_in_risc?
    IdentityConfig
      .store
      .allowed_client_id_in_risc_service_providers.include?(issuer)
  end

  def display_name
    friendly_name || agency.name || issuer
  end

  def agency_name
    agency.name
  end

  private

  def attempts_config
    IdentityConfig.store.allowed_attempts_providers.find do |config|
      config['issuer'] == issuer
    end
  end

  # @return [String,nil]
  def load_cert(cert)
    if cert.include?('-----BEGIN CERTIFICATE-----')
      cert
    elsif (cert_file = Rails.root.join('certs', 'sp', "#{cert}.crt")) && File.exist?(cert_file)
      File.read(cert_file)
    end
  end
end
