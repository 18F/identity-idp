class AddWebauthnPlatformRecommendedDismissedAtToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :webauthn_platform_recommended_dismissed_at, :datetime, default: nil, comment: 'sensitive=false'
  end
end
