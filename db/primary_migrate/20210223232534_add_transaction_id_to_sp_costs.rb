class AddTransactionIdToSpCosts < ActiveRecord::Migration[6.1]
  def change
    add_column :sp_costs, :transaction_id, :string, null: true
  end
end
