class AddGpoVerificationExpiredAtToProfiles < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :profiles, :gpo_verification_expired_at, :datetime
    add_index :profiles, :gpo_verification_expired_at, algorithm: :concurrently
  end
end
