class DropUnusedServiceProviderColumns < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :service_providers, :deal_id, :string }
    safety_assured { remove_column :service_providers, :agency, :string }
    safety_assured { remove_column :service_providers, :fingerprint, :string }
    safety_assured { remove_column :service_providers, :cert, :string }
  end
end
