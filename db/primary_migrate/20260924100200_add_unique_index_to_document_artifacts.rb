class AddUniqueIndexToDocumentArtifacts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :document_artifacts, %i[document_capture_session_id image_type],
              unique: true, algorithm: :concurrently,
              name: 'index_document_artifacts_on_capture_session_and_image_type'
  end
end
