class UpdateEncryptedOtpSecretKeyLength < ActiveRecord::Migration[4.2]
  def change
    change_column :users, :encrypted_otp_secret_key, :text
  end
end
