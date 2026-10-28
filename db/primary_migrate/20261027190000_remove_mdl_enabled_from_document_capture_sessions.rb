class RemoveMdlEnabledFromDocumentCaptureSessions < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :document_capture_sessions, :mdl_enabled, :boolean, comment: 'sensitive=false'
    end
  end
end
