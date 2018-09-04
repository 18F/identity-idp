class RecoveryCodesRemoveCodeAddEncryptedCode < ActiveRecord::Migration[5.1]
  def change
    safety_assured { add_column :recovery_codes, :encrypted_code, :string }
    safety_assured { remove_column :recovery_codes, :code }
  end
end
