class AddIndexToStatusCheckAttemptedAtInPersonEnrollments < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :in_person_enrollments, :status_check_attempted_at, where: '(status = 1)', algorithm: :concurrently
  end
end
