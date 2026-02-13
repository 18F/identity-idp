class AddEmailaddressAttributeEnabledToServiceProvider < ActiveRecord::Migration[8.0]
  def change
    add_column :service_providers, :emailaddress_attribute_enabled, :boolean, default: false, comment: 'sensitive=false'
  end
end
