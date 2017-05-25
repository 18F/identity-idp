class AddOtpRateLimitingToUsers < ActiveRecord::Migration
  def change
    add_column :users, :otp_send_count, :integer, default: 0
    add_column :users, :otp_last_sent_at, :timestamp
  end
end
