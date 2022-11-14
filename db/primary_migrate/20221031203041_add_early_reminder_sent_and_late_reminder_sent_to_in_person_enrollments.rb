class AddEarlyReminderSentAndLateReminderSentToInPersonEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :early_reminder_sent, :boolean, default: false, comment: "early reminder to complete IPP before deadline sent"
    add_column :in_person_enrollments, :late_reminder_sent, :boolean, default: false, comment: "late reminder to complete IPP before deadline sent"
  end
end
