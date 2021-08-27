class ChangeTotpTimestampToInteger < ActiveRecord::Migration[5.1]
  def change
    remove_column :users, :totp_timestamp, :timestamp
    add_column :users, :totp_timestamp, :integer
  end
end
