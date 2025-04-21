class CreateDuplicateProfileConfirmations < ActiveRecord::Migration[8.0]
  def change
    create_table :duplicate_profile_confirmations do |t|
      t.references :profile, foreign_key: true, null: false, comment: 'sensitive=false'
      t.timestamp :confirmed_at, null: false, comment: 'sensitive=false'
      t.json :duplicate_profile_ids, null: false, comment: 'sensitive=false'
      t.boolean :confirmed_all, comment: 'sensitive=false'

      t.timestamps comment: 'sensitive=false'
    end
  end
end
