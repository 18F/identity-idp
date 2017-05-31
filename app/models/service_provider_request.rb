class ServiceProviderRequest < ActiveRecord::Base
  def self.from_uuid(uuid)
    find_by(uuid: uuid) || NullServiceProviderRequest.new
  end
end
