class AddAalAndIalToServiceProvider < ActiveRecord::Migration[5.1]
  def change
    add_column :service_providers, :aal, :integer
    add_column :service_providers, :ial, :integer
  end
end
