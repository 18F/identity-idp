class Identity < ActiveRecord::Base
  include NonNullUuid

  belongs_to :user
  has_many :sessions
  validates :service_provider, presence: true

  LOCAL = 'login.gov'.freeze

  def deactivate(session_id = nil)
    if session_id
      sessions.where(session_id: session_id).destroy_all
    else
      sessions.destroy_all
    end
  end

  def sp_metadata
    ServiceProvider.new(service_provider).metadata
  end

  def display_name
    sp_metadata[:friendly_name] || sp_metadata[:agency] || service_provider
  end

  def decorate
    IdentityDecorator.new(self)
  end
end
