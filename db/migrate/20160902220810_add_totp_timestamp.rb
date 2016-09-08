class AddTotpTimestamp < ActiveRecord::Migration
  def change
    add_column :users, :totp_timestamp, :timestamp
  end
end
