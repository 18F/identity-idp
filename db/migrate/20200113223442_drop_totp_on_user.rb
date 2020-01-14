class DropTotpOnUser < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      remove_column :users, :encrypted_otp_secret_key
      remove_column :users, :totp_timestamp
    end
  end
end
