class AddNativeToServiceProvider < ActiveRecord::Migration
  def change
    add_column :service_providers, :native, :boolean, default: false, null: false
  end
end
