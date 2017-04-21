class ServiceProviderRequest < ActiveRecord::Base
  belongs_to :service_provider, foreign_key: :issuer, primary_key: :issuer

  def self.from_uuid(uuid)
    find_by(uuid: uuid) || NullServiceProviderRequest.new
  end
end
