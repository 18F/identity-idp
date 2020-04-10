class AddLivenessCheckingEnabledToServiceProviders < ActiveRecord::Migration[5.1]
  def change
    add_column :service_providers, :liveness_checking_enabled, :boolean
  end
end
