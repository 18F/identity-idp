class AddFraudReviewPendingToProfiles < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :fraud_review_pending, :boolean, default: false
  end
end
