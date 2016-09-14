class AddUsersIdvAttemptedAt < ActiveRecord::Migration
  def change
    add_column :users, :idv_attempted_at, :datetime
  end
end
