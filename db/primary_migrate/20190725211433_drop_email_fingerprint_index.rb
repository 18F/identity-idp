class DropEmailFingerprintIndex < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def up
    remove_index :users, :email_fingerprint
  end

  def down
    add_index :users, :email_fingerprint, unique: true, algorithm: :concurrently
  end
end
