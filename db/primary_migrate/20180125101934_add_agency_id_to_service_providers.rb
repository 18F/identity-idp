class AddAgencyIdToServiceProviders < ActiveRecord::Migration[5.1]
  def change
    add_column :service_providers, :agency_id, :integer
  end
end
