class DropRedirectUriFromServiceProviders < ActiveRecord::Migration[5.1]
  def change
    remove_column :service_providers, :redirect_uri, :string
  end
end
