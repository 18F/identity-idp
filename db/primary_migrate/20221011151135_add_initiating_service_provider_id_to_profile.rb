class AddInitiatingServiceProviderIdToProfile < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :initiating_service_provider_id, :bigint, null: true
  end
end
