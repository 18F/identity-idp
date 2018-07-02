class ServiceProviderRequest < ApplicationRecord
  def self.from_uuid(uuid)
    find_by(uuid: uuid) || NullServiceProviderRequest.new
  rescue ArgumentError # a null byte in the uuid will raise this
    NullServiceProviderRequest.new
  end
end
