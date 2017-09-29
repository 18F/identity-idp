class AddUspsConfirmations < ActiveRecord::Migration[4.2]
  def change
    create_table :usps_confirmations, force: :cascade do |t|
      t.text     :entry, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
  end
end
