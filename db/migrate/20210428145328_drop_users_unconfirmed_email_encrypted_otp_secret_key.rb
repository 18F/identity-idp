class DropUsersUnconfirmedEmailEncryptedOtpSecretKey < ActiveRecord::Migration[6.1]
  def change
    remove_index :users, column: :unconfirmed_email
    remove_index :users, column: :encrypted_otp_secret_key
    safety_assured { remove_column :users, :unconfirmed_email }
    safety_assured { remove_column :users, :encrypted_otp_secret_key }
  end
end
