class AddEncryptedRecoveryCodeDigestToUser < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :encrypted_recovery_code_digest, :string
  end
end
