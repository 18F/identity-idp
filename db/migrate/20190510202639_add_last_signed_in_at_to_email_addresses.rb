class AddLastSignedInAtToEmailAddresses < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :email_addresses, :last_sign_in_at, :datetime
    add_index(
      :email_addresses,
      :last_sign_in_at,
      order: { last_sign_in_at: :desc },
      algorithm: :concurrently,
    )
  end
end
