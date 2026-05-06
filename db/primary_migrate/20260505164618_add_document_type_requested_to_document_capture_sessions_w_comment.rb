class AddDocumentTypeRequestedToDocumentCaptureSessionsWComment < ActiveRecord::Migration[8.0]
  def up
    add_column :document_capture_sessions, :document_type_requested, :integer, comment: 'sensitive=false'
  end

  def down
    remove_column :document_capture_sessions, :document_type_requested
  end
end
