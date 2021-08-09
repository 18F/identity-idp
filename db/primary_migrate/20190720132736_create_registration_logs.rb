class CreateRegistrationLogs < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    create_table :registration_logs do |t|
      t.integer  :user_id, null: false
      t.datetime :submitted_at, null: false
      t.datetime :confirmed_at
      t.datetime :password_at
      t.string   :first_mfa
      t.datetime :first_mfa_at
      t.string   :second_mfa
      t.datetime :registered_at
    end
    add_index :registration_logs, %i[user_id], algorithm: :concurrently, unique: true
    add_index :registration_logs, %i[submitted_at], algorithm: :concurrently
    add_index :registration_logs, %i[registered_at], algorithm: :concurrently
  end
end
