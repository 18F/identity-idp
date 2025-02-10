class RenameSocureDocvTokenInDocumentCaptureSession < ActiveRecord::Migration[7.1]
  def change
    safety_assured { rename_column :document_capture_sessions, :socure_docv_token, :socure_docv_transaction_token }
  end
end
