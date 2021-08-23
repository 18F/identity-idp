class AddIal2QuotaToServiceProviders < ActiveRecord::Migration[5.1]
  def change
    add_column :service_providers, :ial2_quota, :integer
  end
end
