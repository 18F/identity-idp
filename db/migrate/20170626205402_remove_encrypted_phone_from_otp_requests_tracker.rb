class RemoveEncryptedPhoneFromOtpRequestsTracker < ActiveRecord::Migration
  def change
    remove_column :otp_requests_trackers, :encrypted_phone, :string
  end
end
