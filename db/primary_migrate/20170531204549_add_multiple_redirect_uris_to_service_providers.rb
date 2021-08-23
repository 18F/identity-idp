class AddMultipleRedirectUrisToServiceProviders < ActiveRecord::Migration[4.2]
  def change
    add_column :service_providers, :redirect_uris, :string, array: true, default: []
  end
end
