class RemoveEncryptedPhoneFromOtpRequestsTracker < ActiveRecord::Migration[4.2]
  def change
    remove_column :otp_requests_trackers, :encrypted_phone, :string
  end
end
