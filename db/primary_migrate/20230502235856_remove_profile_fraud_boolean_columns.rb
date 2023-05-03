class RemoveProfileFraudBooleanColumns < ActiveRecord::Migration[7.0]
  def change
    safety_assured {
      remove_column :profiles, :fraud_review_pending, :boolean
      remove_column :profiles, :fraud_rejection, :boolean
    }
  end
end
