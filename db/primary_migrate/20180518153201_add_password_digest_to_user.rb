class AddPasswordDigestToUser < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :password_digest, :string
    change_column_default :users, :password_digest, ""
  end

  def down
    remove_column :users, :password_digest
  end
end
