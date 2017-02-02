class AddOtpDeliveryPreferenceToUser < ActiveRecord::Migration
  def change
    add_column :users, :otp_delivery_preference, :integer, default: 0, index: true, null: false
  end
end
