class AddProfileIdToDocumentCaptureSessions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :document_capture_sessions, :profile,
                  null: true, index: { algorithm: :concurrently }, comment: 'sensitive=false'
    # Nullify rather than restrict: a capture session must never block profile
    # (and therefore account) deletion.
    add_foreign_key :document_capture_sessions, :profiles, on_delete: :nullify, validate: false
  end
end
