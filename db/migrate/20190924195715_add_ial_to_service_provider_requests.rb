class AddIalToServiceProviderRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :service_provider_requests, :ial, :string
  end
end
