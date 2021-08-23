class DocumentCaptureSessionsResultIdIndex < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :document_capture_sessions, ["result_id"], algorithm: :concurrently
  end
end
