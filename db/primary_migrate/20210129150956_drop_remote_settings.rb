class DropRemoteSettings < ActiveRecord::Migration[6.1]
  def change
    drop_table :remote_settings do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.text :contents, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index :name, name: :index_remote_settings_on_name, unique: true
    end
  end
end
