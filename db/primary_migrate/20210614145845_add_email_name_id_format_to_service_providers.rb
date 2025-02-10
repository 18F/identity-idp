class AddEmailNameIdFormatToServiceProviders < ActiveRecord::Migration[6.1]
  def change
    add_column :service_providers, :email_nameid_format_allowed, :boolean
    change_column_default :service_providers, :email_nameid_format_allowed, from: nil, to: false
  end
end
