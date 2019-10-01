class ServiceProviderRequest < ApplicationRecord
  def self.create(attributes)
    attributes[:loa] = attributes[:ial]
    super
  end

  def self.from_uuid(uuid)
    record = find_by(uuid: uuid) || NullServiceProviderRequest.new
    record.ial = record.loa if record && !record.instance_of?(NullServiceProviderRequest)
    record
  rescue ArgumentError # a null byte in the uuid will raise this
    NullServiceProviderRequest.new
  end

  def ial
    loa
  end

  def ial=(val)
    self.loa = val
  end
end
