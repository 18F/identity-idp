class CreateDeletedUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :deleted_users do |t|
      t.integer :user_id, null: false
      t.string :uuid, null: false
      t.datetime :user_created_at, null: false
      t.datetime :deleted_at, null: false
    end
    add_index :deleted_users, %i[user_id], unique: true
    add_index :deleted_users, %i[uuid], unique: true

    remove_foreign_key :events, :users
  end
end
