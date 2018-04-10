class AddChangePhoneEvents < ActiveRecord::Migration[5.1]
  def change
    create_table :change_phone_events do |t|
      t.integer :user_id, null: false
      t.datetime :created_at, null: false
      t.integer :event_type, null: false
      t.string :data
      t.index ['user_id','created_at'], name: 'index_change_phone_events_on_user_id_created_at'
    end
  end
end
