class AddSaltedCodeFingerprintSaltCostToBackupCodeConfigurations < ActiveRecord::Migration[6.1]
  def change
    add_column :backup_code_configurations, :salted_code_fingerprint, :string, limit: 255
    add_column :backup_code_configurations, :code_salt, :string, limit: 255
    add_column :backup_code_configurations, :code_cost, :string, limit: 20
  end
end
