class DropSpReturnLogsRequestedAtIndexes < ActiveRecord::Migration[6.1]
  def change
    remove_index :sp_return_logs, column: [:requested_at], name: "index_sp_return_logs_on_requested_at"
    remove_index :sp_return_logs, column: [:issuer, :requested_at], name: "index_sp_return_logs_on_issuer_and_requested_at"
  end
end
