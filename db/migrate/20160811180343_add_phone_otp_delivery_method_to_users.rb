class AddPhoneOtpDeliveryMethodToUsers < ActiveRecord::Migration
  def change
  	add_column :users, :phone_sms_enabled, :boolean, default: true
  end
end
