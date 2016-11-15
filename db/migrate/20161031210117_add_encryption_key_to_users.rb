class AddEncryptionKeyToUsers < ActiveRecord::Migration
  def change
    add_column :users, :encryption_key, :string
  end
end
