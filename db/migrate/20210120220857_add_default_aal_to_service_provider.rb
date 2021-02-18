class AddDefaultAalToServiceProvider < ActiveRecord::Migration[6.1]
  def up
    add_column :service_providers, :default_aal, :integer
  end

  def down
    remove_column :service_providers, :default_aal
  end
end
