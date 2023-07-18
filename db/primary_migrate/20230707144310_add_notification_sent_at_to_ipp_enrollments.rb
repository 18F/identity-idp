class AddNotificationSentAtToIppEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :notification_sent_at, :datetime,
               comment: 'The time a notification was sent'
  end
end
