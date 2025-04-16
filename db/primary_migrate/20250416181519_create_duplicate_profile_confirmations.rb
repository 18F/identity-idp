class CreateDuplicateProfileConfirmations < ActiveRecord::Migration[8.0]
  def change
    create_table :duplicate_profile_confirmations do |t|
      t.references :profile, foreign_key: true, null: false
      t.timestamp :confirmed_at, null: false
      t.json :duplicate_profiles, null: false
      t.boolean :confirmed_all, null: false

      t.timestamps
    end
  end
end
