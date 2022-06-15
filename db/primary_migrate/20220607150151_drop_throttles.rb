class DropThrottles < ActiveRecord::Migration[6.1]
  def change
    drop_table "throttles" do |t|
      t.integer "user_id"
      t.integer "throttle_type", null: false
      t.datetime "attempted_at"
      t.integer "attempts", default: 0
      t.integer "throttled_count"
      t.string "target"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["target", "throttle_type"], name: "index_throttles_on_target_and_throttle_type"
      t.index ["updated_at"], name: "index_throttles_on_updated_at"
      t.index ["user_id", "throttle_type"], name: "index_throttles_on_user_id_and_throttle_type"
    end
  end
end
