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

  def decorate
    IdentityDecorator.new(self)
  end
end
