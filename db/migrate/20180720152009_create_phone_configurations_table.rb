class CreatePhoneConfigurationsTable < ActiveRecord::Migration[5.1]
  def change
    create_table :phone_configurations do |t|
      t.references :user, null: false
      t.text :encrypted_phone, null: false
      t.integer :delivery_preference, default: 0, null: false
      t.boolean :mfa_enabled, default: true, null: false
      t.timestamp :confirmation_sent_at
      t.timestamp :confirmed_at
      t.timestamps
    end
  end
end
