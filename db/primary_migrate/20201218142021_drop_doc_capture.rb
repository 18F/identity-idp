class DropDocCapture < ActiveRecord::Migration[6.0]
  def change
    drop_table :doc_captures do |t|
      t.integer :user_id, null: false
      t.string :request_token, null: false
      t.datetime :requested_at, null: false
      t.string :acuant_token
      t.boolean :ial2_strict
      t.string :issuer
      t.timestamps
      t.index :request_token, name: :index_doc_captures_on_request_token, unique: true
      t.index :user_id, name: :index_doc_captures_on_user_id, unique: true
    end
  end
end
