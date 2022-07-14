class DropTotpTimestampFromUsers < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :users, :totp_timestamp, :integer }
  end
end
