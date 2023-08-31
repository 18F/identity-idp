class DropIrsAttemptApiLogFiles < ActiveRecord::Migration[7.0]
  def change
    drop_table :irs_attempt_api_log_files do |t|
      t.string "filename"
      t.string "iv"
      t.text "encrypted_key"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "requested_time"
    end
  end
end
