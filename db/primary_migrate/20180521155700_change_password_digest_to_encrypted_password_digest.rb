class ChangePasswordDigestToEncryptedPasswordDigest < ActiveRecord::Migration[5.1]
  def up
    # The code that uses this column has not been deployed yet
    safety_assured { remove_column :users, :password_digest }
    add_column :users, :encrypted_password_digest, :string
    change_column_default :users, :encrypted_password_digest, ""
  end

  def down
    remove_column :users, :encrypted_password_digest
    add_column :users, :password_digest, :string
    change_column_default :users, :password_digest, ""
  end
end
