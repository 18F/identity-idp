class DropServiceProviderRequests < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      drop_table :service_provider_requests
    end
  end
end
