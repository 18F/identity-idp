class AddMdlEnabledToDocumentCaptureSessionsWComment < ActiveRecord::Migration[8.0]
  def change
    add_column :document_capture_sessions, :mdl_enabled, :boolean, comment: 'sensitive=false'
  end
end
