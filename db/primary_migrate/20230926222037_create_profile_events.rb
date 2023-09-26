class CreateProfileEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :profile_events do |t|
      t.string :type
      t.references :profile, foreign_key: true
      t.jsonb :data
      t.jsonb :metadata
      t.jsonb :encrypted_payload
      t.jsonb :unencrypted_payload

      t.timestamps
    end
  end
end
