class AddColumnsToSpReturnLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :sp_return_logs, :profile_id, :bigint, null: true
    add_column :sp_return_logs, :profile_verified_at, :datetime, null: true
    add_column :sp_return_logs, :profile_requested_issuer, :string, null: true
  end
end