class DropOtpRequestsTrackers < ActiveRecord::Migration[7.0]
  def change
    drop_table :otp_requests_trackers do |t|
      t.datetime "otp_last_sent_at", precision: nil
      t.integer "otp_send_count", default: 0
      t.string "attribute_cost"
      t.string "phone_fingerprint", default: "", null: false
      t.datetime "created_at", precision: nil
      t.datetime "updated_at", precision: nil
      t.boolean "phone_confirmed", default: false
      t.index ["phone_fingerprint", "phone_confirmed"], name: "index_on_phone_and_confirmed", unique: true
    end
  end
end
