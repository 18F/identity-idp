class AddRequestedAttributesToServiceProviderRequest < ActiveRecord::Migration
  def change
    add_column :service_provider_requests, :requested_attributes, :string, array: true, default: []
  end
end
