class AddCancelledAtToDocumentCaptureSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :document_capture_sessions, :cancelled_at, :datetime, null: true
  end
end
