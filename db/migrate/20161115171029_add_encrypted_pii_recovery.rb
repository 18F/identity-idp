class AddEncryptedPiiRecovery < ActiveRecord::Migration
  def change
    add_column :profiles, :encrypted_pii_recovery, :text
  end
end
