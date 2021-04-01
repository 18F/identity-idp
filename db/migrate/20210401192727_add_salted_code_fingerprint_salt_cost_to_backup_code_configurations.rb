class AddSaltedCodeFingerprintSaltCostToBackupCodeConfigurations < ActiveRecord::Migration[6.1]
  def change
    add_column :backup_code_configurations, :salted_code_fingerprint, :string
    add_column :backup_code_configurations, :code_salt, :string
    add_column :backup_code_configurations, :code_cost, :string
  end
end
