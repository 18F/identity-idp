class AddIndexToStatusCheckAttemptedAtInPersonEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_index :in_person_enrollments, :status_check_attempted_at
  end
end
