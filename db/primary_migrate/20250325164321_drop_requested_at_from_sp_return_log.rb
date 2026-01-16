class DropRequestedAtFromSpReturnLog < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :sp_return_logs, :requested_at }
  end
end
