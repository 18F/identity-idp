class DropUsersUnlockToken < ActiveRecord::Migration[6.1]
  def change
    remove_index :users, column: :unlock_token
    safety_assured { remove_column :users, :unlock_token }
  end
end
