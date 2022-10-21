class AllowNullProfilesOnInPersonEnrollments < ActiveRecord::Migration[7.0]
  def change
    change_column_null :in_person_enrollments, :profile_id, true
  end
end
