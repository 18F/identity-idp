class AddEventsTable < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.references :user, index: true, foreign_key: true, null: false
      t.integer  :event_type,     limit: 4,   null: false
      t.timestamps null: false
    end
  end
end
