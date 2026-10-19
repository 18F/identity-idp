class ValidateProfileForeignKeyOnDocumentCaptureSessions < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :document_capture_sessions, :profiles
  end
end
