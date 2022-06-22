class AddOcrConfirmationPendingToDocumentCaptureSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :document_capture_sessions, :ocr_confirmation_pending, :boolean, default: false
  end
end
