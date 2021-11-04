class ChangeBackupCodeConfigurationsAllowNullEncryptedCode < ActiveRecord::Migration[6.1]
  def change
    change_column_null :backup_code_configurations, :encrypted_code, true
  end
end
