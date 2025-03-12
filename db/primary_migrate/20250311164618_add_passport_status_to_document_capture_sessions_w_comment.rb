class AddPassportStatusToDocumentCaptureSessionsWComment < ActiveRecord::Migration[7.2]
  def up
    add_column :document_capture_sessions, :passport_status, :string, comment: 'sensitive=false'
  end

  def down
    remove_column :document_capture_sessions, :passport_status
  end
end
