class AddNotificationPhoneConfigurationsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :notification_phone_configurations do |t|
      t.references :in_person_enrollment, null: false, index: { name: 'index_notification_phone_configurations_on_enrollment_id' }
      t.text :encrypted_phone, comment: 'Encrypted phone number to send notifications to. Will be NULL after a notification is sent'
      t.timestamp :notification_sent_at, comment: 'Timestamp when a notification was sent to the phone number'
      t.timestamps
    end
  end
end
