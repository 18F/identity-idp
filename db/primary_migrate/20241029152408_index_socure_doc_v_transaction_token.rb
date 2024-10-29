class IndexSocureDocVTransactionToken < ActiveRecord::Migration[7.2]
  def change
    add_index :document_capture_sessions, %i[socure_docv_transaction_token], algorithm: :concurrently, where: "(socure_docv_transaction_token IS NOT NULL)", unique: true
  end
end
