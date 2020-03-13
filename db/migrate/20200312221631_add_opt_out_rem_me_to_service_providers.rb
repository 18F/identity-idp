class AddOptOutRemMeToServiceProviders < ActiveRecord::Migration[5.1]
  def change
    add_column :service_providers, :opt_out_rem_me, :boolean, default: false, null: false
  end
end
