class AddExpirationNoticeSentAtToUspsConfirmationCodes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :usps_confirmation_codes, :expiration_notice_sent_at, :datetime, precision: nil
    add_index :usps_confirmation_codes, :expiration_notice_sent_at, algorithm: :concurrently
  end
end
