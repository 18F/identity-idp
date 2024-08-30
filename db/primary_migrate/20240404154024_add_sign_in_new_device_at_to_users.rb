class AddSignInNewDeviceAtToUsers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :users, :sign_in_new_device_at, :datetime
    add_index :users, :sign_in_new_device_at, algorithm: :concurrently
  end
end
