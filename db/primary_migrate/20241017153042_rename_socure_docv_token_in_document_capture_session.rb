class RenameSocureDocvTokenInDocumentCaptureSession < ActiveRecord::Migration[7.1]
  def change
    rename_column :document_capture_sessions, :socure_doc_token, :socure_docv_transaction_token
  end
end
