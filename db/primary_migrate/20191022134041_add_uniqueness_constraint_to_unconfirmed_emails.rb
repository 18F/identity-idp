class AddUniquenessConstraintToUnconfirmedEmails < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index(
      :email_addresses,
      %i[email_fingerprint user_id],
      unique: true,
      algorithm: :concurrently,
    )
  end
end
