class AddDeadlinePassedSentToInPersonEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :deadline_passed_sent, :boolean, default: false, comment: "deadline passed email sent for expired enrollment"
  end
end
