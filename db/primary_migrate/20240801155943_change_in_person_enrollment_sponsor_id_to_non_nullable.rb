class ChangeInPersonEnrollmentSponsorIdToNonNullable < ActiveRecord::Migration[7.1]
  def change
    add_check_constraint :in_person_enrollments, "sponsor_id IS NOT NULL", name: "in_person_enrollments_sponsor_id_null", validate: false
  end
end
