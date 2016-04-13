class Identity < ActiveRecord::Base
  include NonNullSessionUuid
  belongs_to :user
  validates :service_provider, presence: true

  def deactivate!
    update(last_authenticated_at: nil)
  end

  def sp_metadata
    ServiceProvider.new(service_provider).metadata
  end
end
