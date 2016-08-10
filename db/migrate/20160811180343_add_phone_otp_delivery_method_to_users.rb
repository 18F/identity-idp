class AddPhoneOtpDeliveryMethodToUsers < ActiveRecord::Migration
  def change
    add_column :users, :sms_otp_delivery, :boolean, default: true
  end
end
