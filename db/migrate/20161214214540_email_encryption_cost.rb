class EmailEncryptionCost < ActiveRecord::Migration
  def up
    add_column :users, :email_encryption_cost, :string
  end

  def down
    remove_column :users, :email_encryption_cost
  end
end
