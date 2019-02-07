class CreateDevices < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    create_table :devices do |t|
      t.integer :user_id, null: false
      t.string :cookie_uuid, null: false
      t.string :user_agent, null: false
      t.timestamp :last_used_at, null: false
      t.string :last_ip, limit: 255, null: false
      t.timestamps
      t.index [:user_id, :cookie_uuid], name: "index_device_user_id_cookie_uuid"
      t.index [:user_id, :last_used_at], name: "index_device_user_id_last_used_at"
    end

    add_column :events, :device_id, :integer
    add_column :events, :ip, :string
    add_index :events, %i[device_id created_at], algorithm: :concurrently
    add_index :events, %i[user_id created_at], algorithm: :concurrently
  end
end
