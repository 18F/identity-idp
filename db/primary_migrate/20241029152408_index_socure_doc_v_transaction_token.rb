class IndexSocureDocVTransactionToken < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def up
    add_index :document_capture_sessions, %i[socure_docv_transaction_token], name: "index_socure_docv_transaction_token", unique: true, algorithm: :concurrently
  end
  def down
    remove_index :document_capture_sessions,  %i[socure_docv_transaction_token]
  end
end
