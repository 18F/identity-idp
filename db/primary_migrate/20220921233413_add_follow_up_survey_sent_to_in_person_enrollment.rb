class AddFollowUpSurveySentToInPersonEnrollment < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :follow_up_survey_sent, :boolean, default: false
  end
end
