class Identity < ApplicationRecord
  include NonNullUuid

  belongs_to :user
  validates :service_provider, presence: true

  def deactivate
    update!(session_uuid: nil)
  end

  def sp_metadata
    ServiceProvider.from_issuer(service_provider).metadata
  end

  def display_name
    sp_metadata[:friendly_name] || sp_metadata[:agency] || service_provider
  end

  def agency_name
    sp_metadata[:agency] || sp_metadata[:friendly_name] || service_provider
  end

  def decorate
    IdentityDecorator.new(self)
  end

  def piv_cac_available?
    PivCacService.piv_cac_available_for_agency?(sp_metadata[:agency])
  end
end
