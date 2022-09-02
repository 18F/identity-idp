class AddAllowThreatmetrixToServiceProviders < ActiveRecord::Migration[7.0]
  def up
    add_column :service_providers, :allow_threatmetrix, :boolean
    change_column_default :service_providers, :allow_threatmetrix, false
  end

  def down
    remove_column :service_providers, :allow_threatmetrix
  end
end
