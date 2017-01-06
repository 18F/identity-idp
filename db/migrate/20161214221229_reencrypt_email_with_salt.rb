class ReencryptEmailWithSalt < ActiveRecord::Migration
  def up
    new_salt = Figaro.env.attribute_encryption_key
    rotate(Figaro.env.password_pepper, new_salt)
  end

  def down
    old_salt = Figaro.env.attribute_encryption_key
    rotate(old_salt, Figaro.env.password_pepper)
  end

  def rotate(old_salt, new_salt)
    key = Figaro.env.attribute_encryption_key
    cost = Figaro.env.attribute_cost
    encryptor = Pii::PasswordEncryptor.new

    User.find_in_batches.with_index do |users, batch|
      puts "Updating batch #{batch}"
      users.each do |user|
        old_uak = UserAccessKey.new(password: key, salt: old_salt, cost: cost)
        new_uak = UserAccessKey.new(password: key, salt: new_salt, cost: cost)
        plain_email = encryptor.decrypt(user.encrypted_email, old_uak)
        ee = EncryptedAttribute.new_from_decrypted(plain_email, new_uak)
        user.update_columns(encrypted_email: ee.encrypted, email_encryption_cost: cost)
      end
    end
  end
end
