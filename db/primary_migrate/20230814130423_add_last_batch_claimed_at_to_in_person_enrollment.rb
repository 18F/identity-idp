class AddLastBatchClaimedAtToInPersonEnrollment < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :last_batch_claimed_at, :datetime
    safety_assured do
      execute <<-SQL
        UPDATE "in_person_enrollments" SET last_batch_claimed_at = status_check_attempted_at;
      SQL
    end
  end
end
