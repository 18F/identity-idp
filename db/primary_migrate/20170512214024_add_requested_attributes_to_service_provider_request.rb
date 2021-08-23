class AddRequestedAttributesToServiceProviderRequest < ActiveRecord::Migration[4.2]
  def change
    add_column :service_provider_requests, :requested_attributes, :string, array: true, default: []
  end
end
