class AddPhoneConfirmedToOtpRequestsTracker < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def up
    add_column :otp_requests_trackers, :phone_confirmed, :boolean
    change_column_default :otp_requests_trackers, :phone_confirmed, false
    add_index :otp_requests_trackers, ["phone_fingerprint","phone_confirmed"], name: "index_on_phone_and_confirmed", unique: true, algorithm: :concurrently
    remove_index :otp_requests_trackers, ["phone_fingerprint"]
  end

  def down
    remove_index :otp_requests_trackers, ["phone_fingerprint","phone_confirmed"]
    remove_column :otp_requests_trackers, :phone_confirmed
    add_index :otp_requests_trackers, ["phone_fingerprint"], unique: true
  end
end
