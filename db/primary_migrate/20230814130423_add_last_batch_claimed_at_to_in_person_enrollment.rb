class AddLastBatchClaimedAtToInPersonEnrollment < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :last_batch_claimed_at, :datetime
    InPersonEnrollment.update_all("last_batch_claimed_at = status_check_attempted_at")
  end
end
