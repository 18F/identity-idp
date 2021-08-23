class AddMadeDefaultAtIndexToPhoneConfigurations < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!
  def change
    add_index :phone_configurations, [:made_default_at, :created_at], order: { released_at: "made_default_at DESC NULLS LAST, created_at" }, name: "index_phone_configurations_on_made_default_at_and_created_at", algorithm: :concurrently
  end
end
