class AddLastBatchClaimAtToInPersonEnrollment < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :last_batch_claim_at, :datetime
  end
end
