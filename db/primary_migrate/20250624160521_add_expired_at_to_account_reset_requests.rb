class AddExpiredAtToAccountResetRequests < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :account_reset_requests, :expired_at, :datetime, comment: 'sensitive=false'
    add_index :account_reset_requests, :expired_at, algorithm: :concurrently
  end
end
