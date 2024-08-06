class ValidateChangeInPersonEnrollmentSponsorIdToNonNullable < ActiveRecord::Migration[7.1]
  def up
    validate_check_constraint :in_person_enrollments, name: "in_person_enrollments_sponsor_id_null"
    change_column_null :in_person_enrollments, :sponsor_id, false
    remove_check_constraint :in_person_enrollments, name: "in_person_enrollments_sponsor_id_null"
  end

  def down
    add_check_constraint :in_person_enrollments, "sponsor_id IS NOT NULL", name: "in_person_enrollments_sponser_id_null", validate: false
    change_column_null :in_person_enrollments, :sponsor_id, true
  end
end
