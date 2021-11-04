class DropBackupCodeConfirmationSymmetricColumns < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :backup_code_configurations, :encrypted_code, :string }
    safety_assured { remove_column :backup_code_configurations, :code_fingerprint, :string }
  end
end
