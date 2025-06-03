class AddSmsWebauthnPlatformRecommendedDismissedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sms_webauthn_platform_recommended_dismissed_at, :datetime, comment: 'sensitive=false'
  end
end
