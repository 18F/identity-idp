class AddInitiatingServiceProviderIssuerToProfile < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :initiating_service_provider_issuer, :string, null: true
  end
end
