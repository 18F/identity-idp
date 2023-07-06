class AddTransportsToWebauthnConfigurations < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :webauthn_configurations, :transports, :string, array: true
  end
end
