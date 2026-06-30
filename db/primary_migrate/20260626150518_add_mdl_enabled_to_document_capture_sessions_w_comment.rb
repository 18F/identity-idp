class AddMdlEnabledToDocumentCaptureSessionsWComment < ActiveRecord::Migration[8.0]
  def up
    add_column :document_capture_sessions, :mdl_enabled, :boolean, comment: 'sensitive=false'
  end

  def down
    remove_column :document_capture_sessions, :mdl_enabled
  end
end
