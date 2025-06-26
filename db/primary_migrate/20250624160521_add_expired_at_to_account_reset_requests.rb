class AddExpiredAtToAccountResetRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :account_reset_requests, :expired_at, :datetime, comment: 'sensitive=false'
  end
end
