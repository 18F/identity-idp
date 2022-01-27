class AddEncryptedRecoveryCodeDigestGeneratedAtToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :encrypted_recovery_code_digest_generated_at, :timestamp, null: true
  end
end
