class UpdateEncryptedOtpSecretKeyLength < ActiveRecord::Migration
  def change
    change_column :users, :encrypted_otp_secret_key, :text
  end
end
