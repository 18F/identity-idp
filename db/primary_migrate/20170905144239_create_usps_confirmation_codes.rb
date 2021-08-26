class CreateUspsConfirmationCodes < ActiveRecord::Migration[5.1]
  def change
    create_table :usps_confirmation_codes do |t|
      t.integer :profile_id, null: false
      t.string :otp_fingerprint, null: false
      t.datetime :code_sent_at, null: false, default: ->{ 'CURRENT_TIMESTAMP' }
      t.index :profile_id, using: :btree

      t.timestamps
    end
  end
end
