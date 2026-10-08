class CreateDocumentMetadata < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :document_metadata do |t|
      t.references :document_capture_session, foreign_key: true, null: false,
                                              index: { unique: true, algorithm: :concurrently },
                                              comment: 'sensitive=false'
      t.references :profile, foreign_key: { on_delete: :nullify },
                             index: { unique: true, algorithm: :concurrently },
                             comment: 'sensitive=false'
      t.string :encrypted_document_data, null: false, comment: 'sensitive=true'

      t.timestamps comment: 'sensitive=false'
    end
  end
end
