class AddNewFraudTimestampsOnProfiles < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  
  def change
    add_column :profiles, :fraud_rejected_at, :datetime
    add_column :profiles, :fraud_reviewing_at, :datetime

    add_index :profiles, :fraud_rejected_at, algorithm: :concurrently
    add_index :profiles, :fraud_reviewing_at, algorithm: :concurrently
  end
end
