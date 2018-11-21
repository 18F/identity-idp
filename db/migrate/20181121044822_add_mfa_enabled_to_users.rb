class AddMfaEnabledToUsers < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :mfa_enabled, :boolean
    change_column_default :users, :mfa_enabled, false
  end

  def down
    remove_column :users, :mfa_enabled
  end
end
