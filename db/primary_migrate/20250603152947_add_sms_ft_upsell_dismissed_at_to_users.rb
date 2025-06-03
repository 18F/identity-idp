class AddSmsFtUpsellDismissedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sms_ft_upsell_dismissed_at, :datetime, comment: 'sensitive=false'
  end
end
