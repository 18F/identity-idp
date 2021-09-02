class AddTimestampsToThrottles < ActiveRecord::Migration[6.1]
  def change
    add_column :throttles, :created_at, :timestamp
    add_column :throttles, :updated_at, :timestamp
  end
end
