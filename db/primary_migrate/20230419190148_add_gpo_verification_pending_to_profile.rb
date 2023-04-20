class AddGpoVerificationPendingToProfile < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :profiles, :gpo_verification_pending_at, :datetime
    add_index :profiles, :gpo_verification_pending_at, algorithm: :concurrently
  end
end
