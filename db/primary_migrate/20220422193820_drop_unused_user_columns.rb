class DropUnusedUserColumns < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      remove_column :users, :idv_attempted_at
      remove_column :users, :idv_attempts
      remove_column :users, :attribute_cost
      remove_column :users, :failed_attempts
      remove_column :users, :locked_at
    end
  end

  def down
    add_column :users, :idv_attempted_at, :datetime
    add_column :users, :idv_attempts, :integer
    add_column :users, :attribute_cost, :text
    add_column :users, :failed_attempts, :integer
    add_column :users, :locked_at, :datetime
  end
end
