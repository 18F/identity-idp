class DropUserIndexInSpReturnLogs < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    remove_index :sp_return_logs,
                 name: 'index_sp_return_logs_on_user_id_and_requested_at',
                 column: [:user_id, :requested_at],
                 unique: false,
                 algorithm: :concurrently
  end
end
