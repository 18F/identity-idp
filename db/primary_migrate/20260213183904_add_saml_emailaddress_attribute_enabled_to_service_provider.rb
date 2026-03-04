class AddSamlEmailaddressAttributeEnabledToServiceProvider < ActiveRecord::Migration[8.0]
  def change
    add_column :service_providers, :saml_emailaddress_attribute_enabled, :boolean, default: false, comment: 'sensitive=false'
  end
end
