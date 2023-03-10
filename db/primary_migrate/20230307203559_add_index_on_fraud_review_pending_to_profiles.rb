class AddIndexOnFraudReviewPendingToProfiles < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :profiles, [:fraud_review_pending], algorithm: :concurrently
  end
end
