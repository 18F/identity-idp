class AddMadeDefaultAtToPhoneConfigurations < ActiveRecord::Migration[5.1]
  def change
    add_column :phone_configurations, :made_default_at, :timestamp
  end
end
