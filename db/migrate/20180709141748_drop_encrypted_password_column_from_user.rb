class DropEncryptedPasswordColumnFromUser < ActiveRecord::Migration[5.1]
  def up
    safety_assured do
      remove_column :users, :encrypted_password
      remove_column :users, :password_salt
      remove_column :users, :password_cost
    end
  end

  def down
    add_column :users, :encrypted_password, :string, limit: 255, default: ''
    add_column :users, :password_salt, :string
    add_column :users, :password_cost, :string
  end
end
