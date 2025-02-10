class AddColumnsForUserSuspension < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :suspended_at, :datetime
    add_column :users, :reinstated_at, :datetime
  end
end
