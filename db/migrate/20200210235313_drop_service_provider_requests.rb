class DropServiceProviderRequests < ActiveRecord::Migration[5.1]
  def change
    drop_table :service_provider_requests
  end
end
