class CreateDevices < ActiveRecord::Migration[5.1]
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

    create_table :device_events do |t|
      # denormalize user_id to not require join when getting events per user in time order
      t.integer :user_id, null: false
      t.integer :device_id, null: false
      t.integer :event_type, null: false
      t.string :ip, limit: 255, null: false
      t.timestamps
      t.index [:device_id, :created_at], name: "index_device_events_on_device_id_created_at"
      t.index [:user_id, :created_at], name: "index_device_events_on_user_id_created_at"
    end
  end
end
