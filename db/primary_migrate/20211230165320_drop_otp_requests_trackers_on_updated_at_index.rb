class DropOtpRequestsTrackersOnUpdatedAtIndex < ActiveRecord::Migration[6.1]
  def up
    remove_index :otp_requests_tracker, name: :index_otp_requests_trackers_on_updated_at
  end

  def down
    add_index :otp_requests_tracker, [:updated_at], name: :index_otp_requests_trackers_on_updated_at
  end
end
