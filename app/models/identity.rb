class Identity < ApplicationRecord
  include NonNullUuid

  # We have a string column "service_provider"
  # but it maps to the "issuer" column in the service_provider table
  alias_attribute :issuer, :service_provider

  belongs_to :user
  validates :issuer, presence: true

  delegate :metadata, to: :sp, prefix: true

  belongs_to :service_provider, foreign_key: 'service_provider', primary_key: 'issuer'

  CONSENT_EXPIRATION = 1.year

  IAL_MAX = 0
  IAL1 = 1
  IAL2 = 2
  IAL2_STRICT = 22

  scope :not_deleted, -> { where(deleted_at: nil) }

  def deactivate
    update!(session_uuid: nil)
  end

  def sp
    @sp ||= ServiceProvider.from_issuer(issuer)
  end

  def display_name
    sp_metadata[:friendly_name] || sp.agency&.name || issuer
  end

  def agency_name
    sp.agency&.name || sp_metadata[:friendly_name] || issuer
  end

  def piv_cac_enabled?
    TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
  end

  def decorate
    IdentityDecorator.new(self)
  end
end
