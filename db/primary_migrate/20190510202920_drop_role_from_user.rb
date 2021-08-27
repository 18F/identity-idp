class DropRoleFromUser < ActiveRecord::Migration[5.1]
  def up
    safety_assured do
      remove_column :users, :role
      remove_column :users, :reset_requested_at
    end
  end

  def down
    add_column :users, :role, :integer
    add_column :users, :reset_requested_at, :datetime
  end
end
