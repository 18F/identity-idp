class RemoveUnusedFromRegistrationLogs < ActiveRecord::Migration[7.0]
  def change
    remove_index :registration_logs, column: :submitted_at, name: "index_registration_logs_on_submitted_at"

    safety_assured do
      remove_column :registration_logs, :submitted_at, :datetime
      remove_column :registration_logs, :confirmed_at, :datetime
      remove_column :registration_logs, :password_at, :datetime
      remove_column :registration_logs, :first_mfa, :string
      remove_column :registration_logs, :first_mfa_at, :datetime
      remove_column :registration_logs, :second_mfa, :string
    end
  end
end
