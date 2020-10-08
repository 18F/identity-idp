class AddVerifyDocFieldsToDocumentCaptureSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :document_capture_sessions, :verify_doc_submitted_at, :timestamp
    add_column :document_capture_sessions, :verify_doc_results_at, :timestamp
    add_column :document_capture_sessions, :verify_doc_results, :string
    add_column :document_capture_sessions, :verify_doc_status, :string
  end
end
