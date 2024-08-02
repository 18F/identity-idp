class AddDocvTransactionTokenToDocumentCaptureSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :document_capture_sessions, :docv_transaction_token, :string
  end
end
