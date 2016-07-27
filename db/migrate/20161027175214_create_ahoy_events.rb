class CreateAhoyEvents < ActiveRecord::Migration
  def change
    create_table :ahoy_events do |t|
      t.string :name, null: false
      t.jsonb :properties
      t.integer :user_id
      t.timestamps
      t.index [:user_id, :name]
      t.index [:name, :created_at]
    end
  end
end
