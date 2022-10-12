class AlterRegistrationLogsNullableSubmittedAt < ActiveRecord::Migration[7.0]
  def up
    safety_assured do
      execute 'ALTER TABLE "registration_logs" ALTER COLUMN submitted_at DROP NOT NULL'
    end
  end

  def down
    safety_assured do
      execute 'ALTER TABLE "registration_logs" ALTER COLUMN submitted_at SET NOT NULL'
    end
  end
end
