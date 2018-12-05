class AddBouncedAtToUspsConfirmationCode < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :usps_confirmation_codes, :bounced_at, :timestamp
    add_index :usps_confirmation_codes, :otp_fingerprint, algorithm: :concurrently
  end
end
