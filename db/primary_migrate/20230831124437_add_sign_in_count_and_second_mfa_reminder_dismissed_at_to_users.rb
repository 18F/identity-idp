class AddSignInCountAndSecondMfaReminderDismissedAtToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :second_mfa_reminder_dismissed_at, :datetime
  end
end
