class DropRememberCreatedAtFromUsers < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :users, :remember_created_at, :datetime
    end
  end
end
