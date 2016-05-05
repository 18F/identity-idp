class RemoveAccountTypeFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :account_type, :integer
  end
end
