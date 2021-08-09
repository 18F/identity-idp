class RemoveAalFromServiceProviders < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :service_providers, :aal, :integer }
  end
end
