class AddFraudStateTimestampsToProfiles < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :fraud_reviewing_at, :timestamp
    add_column :profiles, :fraud_rejected_at, :timestamp
    add_column :profiles, :fraud_passed_at, :timestamp
  end
end
