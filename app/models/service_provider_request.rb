class ServiceProviderRequest < ActiveRecord::Base
  def self.find_by(*args)
    super || NullServiceProviderRequest.new
  end
end
