class AddPiiEncryptionKeyToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :password_pii_encryption_public_key, :string
    add_column :users, :password_encrypted_pii_encryption_key, :string
    add_column :users, :recovery_pii_encryption_public_key, :string
    add_column :users, :recovery_encrypted_pii_encryption_key, :string
  end
end
