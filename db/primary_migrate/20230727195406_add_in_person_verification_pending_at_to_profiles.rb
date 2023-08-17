class AddInPersonVerificationPendingAtToProfiles < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :profiles, :in_person_verification_pending_at, :datetime
  end
end
