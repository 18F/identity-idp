class AddPkceToServiceProvider < ActiveRecord::Migration[5.1]
  def up
    add_column :service_providers, :pkce, :boolean
  end

  def down
    remove_column :service_providers, :pkce
  end
end
