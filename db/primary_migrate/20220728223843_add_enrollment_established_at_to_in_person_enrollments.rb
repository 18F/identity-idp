class AddEnrollmentEstablishedAtToInPersonEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :enrollment_established_at, :datetime, null: true, comment: "When the enrollment was successfully established"
  end
end
