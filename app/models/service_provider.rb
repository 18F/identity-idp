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

  DEFAULT_LOGO = 'generic.svg'

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

  def facial_match_ial_allowed?
    IdentityConfig.store.facial_match_general_availability_enabled
  end

  def sp_logo_url
    if FeatureManagement.logo_upload_enabled? && remote_logo_key.present?
      s3_logo_url
    else
      legacy_logo_url
    end
  end

  def logo_is_email_compatible?
    sp_logo_url.end_with?('.png')
  end

  private

  def s3_logo_url
    region = IdentityConfig.store.aws_region
    bucket = IdentityConfig.store.aws_logo_bucket
    key = remote_logo_key

    "https://s3.#{region}.amazonaws.com/#{bucket}/#{key}"
  end

  def legacy_logo_url
    ActionController::Base.helpers.image_path("sp-logos/#{logo || DEFAULT_LOGO}")
  rescue Propshaft::MissingAssetError
    ''
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
