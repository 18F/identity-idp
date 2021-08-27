class AddX509DnUuidToUsersTable < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :x509_dn_uuid, :string
    add_index :users, :x509_dn_uuid, unique: true
  end

  def down
    remove_index :users, :x509_dn_uuid
    remove_column :users, :x509_dn_uuid
  end
end
