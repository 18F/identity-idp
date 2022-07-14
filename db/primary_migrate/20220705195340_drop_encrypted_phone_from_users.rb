class DropEncryptedPhoneFromUsers < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :users, :encrypted_phone, :string }
  end
end
