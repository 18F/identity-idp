class AddDefaultToPhoneConfigurations < ActiveRecord::Migration[5.1]
  def change
    add_column :phone_configurations, :default, :boolean
  end
end
