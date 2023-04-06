class AddFraudRejectionAtToProfiles < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  
  def change
    add_column :profiles, :fraud_rejection_at, :datetime
    add_index :profiles, :fraud_rejection_at, algorithm: :concurrently
  end
end
