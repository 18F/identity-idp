class CreateDocCaptures < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    create_table :doc_captures do |t|
      t.integer :user_id, null: false
      t.string :request_token, null: false
      t.datetime :requested_at, null: false
      t.string :acuant_token
      t.timestamps
    end
    add_index :doc_captures, %i[user_id], unique: true, using: :btree
    add_index :doc_captures, %i[request_token], unique: true, using: :btree
  end
end
