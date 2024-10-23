class DropDeprecatedUserColumn2 < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :users, :password_compromised_checked_at, :datetime
    end
  end
end
