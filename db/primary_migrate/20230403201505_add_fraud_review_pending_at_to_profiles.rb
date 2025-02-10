class AddFraudReviewPendingAtToProfiles < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  
  def change
    add_column :profiles, :fraud_review_pending_at, :datetime
    add_index :profiles, :fraud_review_pending_at, algorithm: :concurrently
  end
end
