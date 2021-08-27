class AddBillableToSpReturnLog < ActiveRecord::Migration[6.1]
  def change
    add_column :sp_return_logs, :billable, :boolean
  end
end
