class RemoveUserIdIndexFromEmailAddress < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    remove_index :email_addresses, name: "index_email_addresses_on_user_id", algorithm: :concurrently
  end
end
