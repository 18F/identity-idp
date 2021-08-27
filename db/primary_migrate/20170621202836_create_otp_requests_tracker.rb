class CreateOtpRequestsTracker < ActiveRecord::Migration[4.2]
  def change
    create_table :otp_requests_trackers do |t|
      t.text :encrypted_phone
      t.timestamp :otp_last_sent_at
      t.integer :otp_send_count, default: 0
      t.string :attribute_cost
      t.string :phone_fingerprint, default: '', null: false

      t.timestamps

      t.index :phone_fingerprint, unique: true
      t.index :updated_at
    end
  end
end
