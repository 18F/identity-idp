class AddIndexToBackupCodeConfiguration < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index(
      :backup_code_configurations,
      %i[created_at user_id],
      order: { created_at: :asc },
      algorithm: :concurrently,
    )
  end
end
