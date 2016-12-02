class AddUserEmailFingerprint < ActiveRecord::Migration
  class User < ActiveRecord::Base
  end

  def up
    add_column :users, :email_fingerprint, :string, default: ''
    add_column :users, :encrypted_email, :text, default: ''
    encrypt_user_emails
    change_column_null :users, :email_fingerprint, false
    change_column_null :users, :encrypted_email, false
    remove_index :users, :email
    rename_column :users, :email, :email_plain
    change_column_null :users, :email_plain, true
  end

  def down
    rename_column :users, :email_plain, :email
    decrypt_user_emails
    change_column_null :users, :email, false
    add_index :users, :email, unique: true
    remove_column :users, :email_fingerprint
    remove_column :users, :encrypted_email
  end

  def encrypt_user_emails
    user_access_key = EncryptedEmail.new_user_access_key
    User.where(encrypted_email: '').each do |user|
      email_address = user.email.present? ? user.email : user.id.to_s
      ee = EncryptedEmail.new_from_email(email_address, user_access_key)
      # must use raw SQL here to change data during the migration transaction.
      execute "UPDATE users SET encrypted_email='#{ee.encrypted}', email_fingerprint='#{ee.fingerprint}' WHERE id=#{user.id}"
    end
  end

  def decrypt_user_emails
    User.where(email: nil).each do |user|
      ee = EncryptedEmail.new(user.encrypted_email)
      escaped = ActiveRecord::Base.connection.quote(ee.decrypted)
      execute "UPDATE users set email=#{escaped} WHERE id=#{user.id}"
    end
  end
end
