# Joins Users to ServiceProviders
class ServiceProviderIdentity < ApplicationRecord
  self.table_name = :identities

  include NonNullUuid

  belongs_to :user
  validates :service_provider, presence: true

  delegate :metadata, to: :sp, prefix: true

  # rubocop:disable Rails/InverseOf
  belongs_to :service_provider_record,
             class_name: 'ServiceProvider',
             foreign_key: 'service_provider',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf

  scope :not_deleted, -> { where(deleted_at: nil) }

  CONSENT_EXPIRATION = 1.year

  def deactivate
    update!(session_uuid: nil)
  end

  def sp
    @sp ||= ServiceProvider.from_issuer(service_provider)
  end

  def display_name
    sp_metadata[:friendly_name] || sp.agency&.name || service_provider
  end

  def agency_name
    sp.agency&.name || sp_metadata[:friendly_name] || service_provider
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

  def service_provider_id
    sp.id
  end

  def happened_at
    last_authenticated_at.in_time_zone('UTC')
  end

  def event_partial
    'accounts/identity_item'
  end
end
