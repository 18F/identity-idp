class AddInPersonEnrollmentPendingAtToProfiles < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :profiles, :in_person_enrollment_pending_at, :datetime
    add_index :profiles, :in_person_enrollment_pending_at, algorithm: :concurrently
  end
end
