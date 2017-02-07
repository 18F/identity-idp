class EncryptOtpSecret < ActiveRecord::Migration
  class User < ActiveRecord::Base
  end

  def up
    encrypt_otp_secret_key
  end

  def down
  end

  def encrypt_otp_secret_key
    User.where.not(otp_secret_key: nil).find_in_batches.with_index do |users, batch|
      users.each do |user|
        encrypted_attribute = EncryptedAttribute.new_from_decrypted(user.otp_secret_key)
        # must use raw SQL here to change data during the migration transaction.
        execute "UPDATE users SET encrypted_otp_secret_key='#{encrypted_attribute.encrypted}' " \
                "WHERE id=#{user.id}"
      end
    end
  end
end
