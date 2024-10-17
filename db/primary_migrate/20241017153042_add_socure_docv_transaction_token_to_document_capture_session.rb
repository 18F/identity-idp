class AddSocureDocvTransactionTokenToDocumentCaptureSession < ActiveRecord::Migration[7.1]
  def change
    add_column :document_capture_sessions, :socure_docv_transaction_token, :string, comment: 'sensitive=false'
  end
end
