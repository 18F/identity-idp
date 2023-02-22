class DeleteIal2Columns < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :document_capture_sessions, :ial2_strict }    
    safety_assured { remove_column :doc_auth_logs, :selfie_view_at }
  end
end
