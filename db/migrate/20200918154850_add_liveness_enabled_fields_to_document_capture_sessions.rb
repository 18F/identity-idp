class AddLivenessEnabledFieldsToDocumentCaptureSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :document_capture_sessions, :ial2_strict, :boolean
    add_column :document_capture_sessions, :issuer, :string
  end
end
