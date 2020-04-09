class DropSsnUniquenessConstraint < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def up
    remove_index :profiles, %i[ssn_signature active]
    remove_index :profiles, %i[user_id ssn_signature active]
  end

  def down
    add_index(
      :profiles,
      %i[ssn_signature active],
      name: :index_profiles_on_ssn_signature_and_active,
      unique: true,
      where: '(active = true)',
      algorithm: :concurrently,
    )
    add_index(
      :profiles,
      %i[user_id ssn_signature active],
      name: :index_profiles_on_user_id_and_ssn_signature_and_active,
      unique: true,
      where: '(active = true)',
      algorithm: :concurrently,
    )
  end
end
