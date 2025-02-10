class AlterRegistrationLogsNullableSubmittedAt < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_column_null :registration_logs, :submitted_at, true
    end
  end
end
