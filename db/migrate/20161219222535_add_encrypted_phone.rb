class AddEncryptedPhone < ActiveRecord::Migration
  def change
    add_column :users, :encrypted_phone, :text
    rename_column :users, :email_encryption_cost, :attribute_cost
  end
end
