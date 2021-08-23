class AddPivCacToServiceProvider < ActiveRecord::Migration[5.1]
  def up
    add_column :service_providers, :piv_cac, :boolean
    change_column_default :service_providers, :piv_cac, false

    add_column :service_providers, :piv_cac_scoped_by_email, :boolean
    change_column_default :service_providers, :piv_cac_scoped_by_email, false
  end

  def down
    remove_column :service_providers, :piv_cac
    remove_column :service_providers, :piv_cac_scoped_by_email
  end
end
