class AddPivCacRecommendedDismissedAtToUser < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :piv_cac_recommended_dismissed_at, :datetime, default: nil
  end
end
