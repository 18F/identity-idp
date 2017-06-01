class AddMultipleRedirectUrisToServiceProviders < ActiveRecord::Migration
  def change
    add_column :service_providers, :redirect_uris, :string, array: true, default: []
  end
end
