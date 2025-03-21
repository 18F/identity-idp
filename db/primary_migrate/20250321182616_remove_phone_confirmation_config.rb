class RemovePhoneConfirmationConfig < ActiveRecord::Migration[8.0]
  def change
    remove_column :phone_configurations, :confirmation_sent_at, :datetime
    remove_column :phone_configurations, :confirmed_at, :datetime
  end
end
