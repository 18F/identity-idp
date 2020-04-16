class AddLogoKeyToServiceProvider < ActiveRecord::Migration[5.2]
  def change
    add_column :service_providers, :logo_key, :string
  end
end
