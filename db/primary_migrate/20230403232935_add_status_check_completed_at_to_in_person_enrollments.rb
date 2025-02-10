class AddStatusCheckCompletedAtToInPersonEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :status_check_completed_at, :datetime,
               comment: 'The last time a status check was successfully completed'
  end
end
