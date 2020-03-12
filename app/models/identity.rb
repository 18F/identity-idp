class Identity < ApplicationRecord
  include NonNullUuid

  belongs_to :user
  validates :service_provider, presence: true

  delegate :metadata, to: :sp, prefix: true

  CONSENT_EXPIRATION = 1.year

  def deactivate
    update!(session_uuid: nil)
  end

  def sp
    @sp ||= ServiceProvider.from_issuer(service_provider)
  end

  def display_name
    sp_metadata[:friendly_name] || sp_metadata[:agency] || service_provider
  end

  def agency_name
    sp_metadata[:agency] || sp_metadata[:friendly_name] || service_provider
  end

  def piv_cac_enabled?
    TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
  end

  def decorate
    IdentityDecorator.new(self)
  end
end
