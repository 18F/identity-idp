class DropDeprecatedUserColumn < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :users, :remember_device_revoked_at, :datetime, precision: nil
    end
  end
end
