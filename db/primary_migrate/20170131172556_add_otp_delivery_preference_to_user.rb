class AddOtpDeliveryPreferenceToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :otp_delivery_preference, :integer, default: 0, index: true, null: false
  end
end
