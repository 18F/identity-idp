class AddReadyForStatusCheckToInPersonEnrollments < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def change
    add_column :in_person_enrollments, :ready_for_status_check, :boolean, default: false
    add_index :in_person_enrollments, :ready_for_status_check, where: "(ready_for_status_check = true)", algorithm: :concurrently
  end
end
