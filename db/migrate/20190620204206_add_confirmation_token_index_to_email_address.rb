class AddConfirmationTokenIndexToEmailAddress < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :email_addresses, :confirmation_token, algorithm: :concurrently, unique: true
  end
end
