class AddRequestedAtToDocumentCaptureSession < ActiveRecord::Migration[5.2]
  def change
    add_column :document_capture_sessions, :requested_at, :timestamp
  end
end
