class AddIndexPassportStatusToDocumentCaptureSessions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_document_capture_sessions_on_passport_status_null_doc_type"

  def up
    add_index(
      :document_capture_sessions,
      :passport_status,
      name: INDEX_NAME,
      where: "document_type_requested IS NULL AND passport_status IS NOT NULL",
      algorithm: :concurrently,
    )
  end

  def down
    remove_index(
      :document_capture_sessions,
      name: INDEX_NAME,
      algorithm: :concurrently,
    )
  end
end
