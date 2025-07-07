class DropDuplicateProfileConfirmations < ActiveRecord::Migration[8.0]
  def change
    drop_table :duplicate_profile_confirmations do |t|
      t.bigint "profile_id", null: false, comment: "sensitive=false"
      t.datetime "confirmed_at", precision: nil, null: false, comment: "sensitive=false"
      t.bigint "duplicate_profile_ids", null: false, comment: "sensitive=false", array: true
      t.boolean "confirmed_all", comment: "sensitive=false"
      t.datetime "created_at", null: false, comment: "sensitive=false"
      t.datetime "updated_at", null: false, comment: "sensitive=false"
      t.index ["profile_id"], name: "index_duplicate_profile_confirmations_on_profile_id"
    end
  end
end
