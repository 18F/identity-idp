class RemoveDeviseSecurityExtensionFields < ActiveRecord::Migration
  def change
    drop_table :old_passwords
    remove_column :users, :password_changed_at, :datetime
  end
end
