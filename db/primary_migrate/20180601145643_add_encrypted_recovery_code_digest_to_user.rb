class AddEncryptedRecoveryCodeDigestToUser < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :encrypted_recovery_code_digest, :string
    change_column_default :users, :encrypted_recovery_code_digest, ""
  end

  def down
    remove_column :users, :encrypted_recovery_code_digest
  end
end
