class AddNotificationPhoneConfigurationsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :notification_phone_configurations do |t|
      t.references :in_person_enrollment, null: false, index: { name: 'index_notification_phone_configurations_on_enrollment_id', unique: true }
      t.text :encrypted_phone, null: false, comment: 'Encrypted phone number to send notifications to'
      t.timestamps
    end
  end
end
