class AddGpoVerificationPendingToProfile < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :profiles, :gpo_verification_pending, :boolean
    add_index :profiles, :gpo_verification_pending, algorithm: :concurrently
  end
end
