class AddIalToSpCosts < ActiveRecord::Migration[5.1]
  def change
    add_column :sp_costs, :ial, :integer
  end
end
