class AddEmailFingerprintIndex < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :email_addresses, :email_fingerprint, algorithm: :concurrently, name: :index_email_addresses_on_all_email_fingerprints
  end
end
