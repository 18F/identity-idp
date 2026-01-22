class AddHybridThreatmetrixSessionIdToDocumentCaptureSession < ActiveRecord::Migration[8.0]
  def change
    add_column :document_capture_sessions, :hybrid_mobile_threatmetrix_session_id, :string, comment: 'sensitive=false'
    add_column :document_capture_sessions, :hybrid_mobile_request_ip, :string, comment: 'sensitive=false'
  end
end
