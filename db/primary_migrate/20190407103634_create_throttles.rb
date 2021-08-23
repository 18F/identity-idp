class CreateThrottles < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    create_table :throttles do |t|
      t.integer :user_id, null: false
      t.integer :throttle_type, null: false
      t.datetime :attempted_at
      t.integer :attempts, default: 0
    end
    add_index :throttles, %i[user_id throttle_type], algorithm: :concurrently
  end
end
