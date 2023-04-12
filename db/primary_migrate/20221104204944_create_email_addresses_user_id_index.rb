class CreateEmailAddressesUserIdIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :email_addresses, [:user_id], algorithm: :concurrently
  end
end
