class CreateDocumentArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :document_artifacts do |t|
      t.references :document_capture_session, foreign_key: true, null: false,
                                              comment: 'sensitive=false'
      t.references :profile, foreign_key: true, comment: 'sensitive=false'
      t.string :image_type, null: false, comment: 'sensitive=false'
      t.string :storage_name, null: false, comment: 'sensitive=false'
      t.string :encrypted_encryption_key, null: false, comment: 'sensitive=true'
      t.string :content_type, null: false, default: 'image/jpeg', comment: 'sensitive=false'

      t.timestamps comment: 'sensitive=false'

      t.index %i[profile_id image_type], unique: true
    end
  end
end
