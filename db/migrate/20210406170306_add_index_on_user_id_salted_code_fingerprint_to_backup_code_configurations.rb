class AddIndexOnUserIdSaltedCodeFingerprintToBackupCodeConfigurations < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :backup_code_configurations,
              [:user_id, :salted_code_fingerprint],
              name: :index_backup_codes_on_user_id_and_salted_code_fingerprint,
              algorithm: :concurrently
  end
end
