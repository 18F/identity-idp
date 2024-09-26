class AddSocureDocvIdToDocumentCaptureSession < ActiveRecord::Migration[7.1]
  def change
    add_column :document_capture_sessions, :socure_docv_token, :string
  end
end
