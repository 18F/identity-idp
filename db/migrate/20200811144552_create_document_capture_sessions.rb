class CreateDocumentCaptureSessions < ActiveRecord::Migration[5.2]
  def change
    create_table :document_capture_sessions do |t|
      t.string :uuid
      t.string :result_id
      t.references :user, foreign_key: true

      t.timestamps

      t.index :uuid
    end
  end
end
