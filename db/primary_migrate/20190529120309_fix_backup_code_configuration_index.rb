class FixBackupCodeConfigurationIndex < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def up
    remove_index :backup_code_configurations, %i[created_at user_id]
    add_index(
      :backup_code_configurations,
      %i[user_id created_at],
      order: { created_at: :asc },
      algorithm: :concurrently,
    )
  end

  def down
    remove_index :backup_code_configurations, %i[user_id created_at]
    add_index(
      :backup_code_configurations,
      %i[created_at user_id],
      order: { created_at: :asc },
      algorithm: :concurrently,
    )
  end
end
