class DropUsersSignInAtSignInIpSignInCount < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      remove_column :users, :sign_in_count
      remove_column :users, :current_sign_in_at
      remove_column :users, :last_sign_in_at
      remove_column :users, :current_sign_in_ip
      remove_column :users, :last_sign_in_ip
    end
  end

  def down
    add_column :users, :sign_in_count, :integer, default: 0, null: false
    add_column :users, :current_sign_in_at, :datetime
    add_column :users, :last_sign_in_at, :datetime
    add_column :users, :current_sign_in_ip, :text
    add_column :users, :last_sign_in_ip, :text
  end
end
