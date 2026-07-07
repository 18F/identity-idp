class AddResetPasswordEmailAddressIdToUsers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  def change
    add_column :users, :reset_password_email_address_id, :bigint, comment: 'sensitive=false'
    add_index :users, :reset_password_email_address_id, algorithm: :concurrently
  end
end