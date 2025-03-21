class ChangeNullConstraintOnSpReturnLog < ActiveRecord::Migration[8.0]
  def change
    change_column_null(:sp_return_logs, :requested_at, true)
  end
end
