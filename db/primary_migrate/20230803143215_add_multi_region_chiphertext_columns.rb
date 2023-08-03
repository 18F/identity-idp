class AddMultiRegionChiphertextColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :encrypted_password_digest_multi_region, :string
    add_column :users, :encrypted_recovery_code_digest_multi_region, :string
    add_column :profiles, :encrypted_pii_multi_region, :text
    add_column :profiles, :encrypted_pii_recovery_multi_region, :text
    add_column :usps_confirmations, :entry_multi_region, :text
  end
end
