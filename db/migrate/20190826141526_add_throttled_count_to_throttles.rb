class AddThrottledCountToThrottles < ActiveRecord::Migration[5.1]

  def change
    add_column :throttles, :throttled_count, :integer
  end
end
