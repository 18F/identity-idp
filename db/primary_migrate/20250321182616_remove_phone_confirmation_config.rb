class RemovePhoneConfirmationConfig < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :phone_configurations, :confirmation_sent_at, :datetime }
  end
end
