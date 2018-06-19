class CreateRemoteSettings < ActiveRecord::Migration[5.1]
  def change
    create_table :remote_settings do |t|
      t.string   "name", null: false
      t.string   "url", null: false
      t.text     "contents", null: false
      t.timestamps
    end
    add_index :remote_settings, ["name"], name: "index_remote_settings_on_name", unique: true, using: :btree
  end
end
