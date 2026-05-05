class AddDocumentTypeToDocumentCaptureSessionsWComment < ActiveRecord::Migration[8.0]
  def up
    add_column :document_capture_sessions, :document_type, :integer, comment: 'sensitive=false'
  end

  def down
    remove_column :document_capture_sessions, :document_type
  end
end
