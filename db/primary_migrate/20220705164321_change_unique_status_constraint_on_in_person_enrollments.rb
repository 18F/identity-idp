class ChangeUniqueStatusConstraintOnInPersonEnrollments < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    remove_index :in_person_enrollments, name: 'index_in_person_enrollments_on_user_id_and_status', algorithm: :concurrently if index_exists?(:in_person_enrollments, [:user_id, :status], name: "index_in_person_enrollments_on_user_id_and_status")
    add_index :in_person_enrollments, [:user_id, :status], unique: true, where: '(status = 1)', algorithm: :concurrently
  end

  def down
    remove_index :in_person_enrollments, name: 'index_in_person_enrollments_on_user_id_and_status', algorithm: :concurrently if index_exists?(:in_person_enrollments, [:user_id, :status], name: "index_in_person_enrollments_on_user_id_and_status")
    add_index :in_person_enrollments, [:user_id, :status], unique: true, where: '(status = 0)', algorithm: :concurrently
  end
end
