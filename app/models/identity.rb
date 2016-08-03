class Identity < ActiveRecord::Base
  belongs_to :user
  validates :service_provider, presence: true

  def deactivate
    update!(last_authenticated_at: nil)
  end

  def sp_metadata
    ServiceProvider.new(service_provider).metadata
  end

  def display_name
    sp_metadata[:friendly_name] || sp_metadata[:agency] || service_provider
  end
end
