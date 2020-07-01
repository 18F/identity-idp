class AddAppIdToServiceProviders < ActiveRecord::Migration[5.2]
  def change
    add_column :service_providers, :app_id, :string
  end
end
