class AddNativeToServiceProvider < ActiveRecord::Migration[4.2]
  def change
    add_column :service_providers, :native, :boolean, default: false, null: false
  end
end
