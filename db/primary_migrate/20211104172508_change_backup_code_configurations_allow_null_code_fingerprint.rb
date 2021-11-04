class ChangeBackupCodeConfigurationsAllowNullCodeFingerprint < ActiveRecord::Migration[6.1]
  def change
    change_column_null :backup_code_configurations, :code_fingerprint, true
  end
end
