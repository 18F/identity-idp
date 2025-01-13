# frozen_string_literal: true

# Joins Users to ServiceProviders
class ServiceProviderIdentity < ApplicationRecord
  self.table_name = :identities

  include NonNullUuid

  belongs_to :user
  validates :service_provider, presence: true

  # rubocop:disable Rails/InverseOf
  belongs_to :deleted_user, foreign_key: 'user_id', primary_key: 'user_id'

  belongs_to :service_provider_record,
             class_name: 'ServiceProvider',
             foreign_key: 'service_provider',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf
  has_one :agency, through: :service_provider_record

  belongs_to :email_address

  scope :not_deleted, -> { where(deleted_at: nil) }

  CONSENT_EXPIRATION = 1.year.freeze

  def deactivate
    update!(session_uuid: nil)
  end

  def sp_metadata
    service_provider_record&.metadata || {}
  end

  def display_name
    sp_metadata[:friendly_name] || service_provider_record&.agency&.name || service_provider
  end

  def agency_name
    service_provider_record&.agency&.name || sp_metadata[:friendly_name] || service_provider
  end

  def piv_cac_enabled?
    TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
  end

  def failure_to_proof_url
    sp_metadata[:failure_to_proof_url]
  end

  def return_to_sp_url
    sp_metadata[:return_to_sp_url]
  end

  def friendly_name
    sp_metadata[:friendly_name]
  end

  def all_email_and_single_email_requested?
    service_provider_record&.attribute_bundle&.include?('all_emails') &&
      service_provider_record&.attribute_bundle.include?('email')
  end

  def service_provider_id
    service_provider_record&.id
  end

  def happened_at
    last_authenticated_at.in_time_zone('UTC')
  end

  def email_address_for_sharing
    if IdentityConfig.store.feature_select_email_to_share_enabled && email_address
      return email_address
    end
    user.last_sign_in_email_address
  end
end
