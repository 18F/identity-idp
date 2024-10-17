class RemoveSocureDocvIdToDocumentCaptureSession < ActiveRecord::Migration[7.1]
  def change
    remove_column :document_capture_sessions, :socure_docv_token
  end
end
