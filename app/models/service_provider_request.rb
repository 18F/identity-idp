class ServiceProviderRequest < ApplicationRecord
  def self.create(attributes)
    attributes[:loa] = (attributes[:ial] == 2 ? 3 : 1)
    super
  end

  def self.from_uuid(uuid)
    find_by(uuid: uuid) || NullServiceProviderRequest.new
  rescue ArgumentError # a null byte in the uuid will raise this
    NullServiceProviderRequest.new
  end
end
