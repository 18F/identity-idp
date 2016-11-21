class AddUserEmailFingerprintIndex < ActiveRecord::Migration
  def change
    add_index :users, :email_fingerprint, unique: true
  end
end
