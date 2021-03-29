class AddMultipleCertsToServiceProviders < ActiveRecord::Migration[6.1]
  def change
    add_column :service_providers, :certs, :string, array: true
  end
end
