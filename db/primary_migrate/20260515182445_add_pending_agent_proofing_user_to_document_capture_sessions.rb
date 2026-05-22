class AddPendingAgentProofingUserToDocumentCaptureSessions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :document_capture_sessions, :pending_agent_proofed_user_at, :datetime, comment: 'sensitive=false'
    add_index :document_capture_sessions, [:user_id, :pending_agent_proofed_user_at], algorithm: :concurrently
  end
end
