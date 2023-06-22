class AddFraudPendingReasonToProfile < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :profiles, :fraud_pending_reason, :integer
    add_index :profiles, :fraud_pending_reason, algorithm: :concurrently
  end
end
