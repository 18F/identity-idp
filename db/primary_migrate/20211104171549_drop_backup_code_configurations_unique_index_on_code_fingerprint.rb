class DropBackupCodeConfigurationsUniqueIndexOnCodeFingerprint < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    remove_index :backup_code_configurations,
                 name: 'index_bcc_on_user_id_code_fingerprint',
                 column: [:user_id, :code_fingerprint],
                 unique: true,
                 algorithm: :concurrently
  end
end
