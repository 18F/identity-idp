class AddDirectOtpToUsers < ActiveRecord::Migration
  def change
    add_column :users, :direct_otp, :string
    add_column :users, :direct_otp_sent_at, :datetime
  end
end
