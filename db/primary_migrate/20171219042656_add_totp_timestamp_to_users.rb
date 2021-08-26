class AddTotpTimestampToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :totp_timestamp, :timestamp
  end
end
