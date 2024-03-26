class AddPivCacRecommendedVisitedAtOnUser < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :piv_cac_recommended_visited_at, :datetime, default: nil
  end
end
