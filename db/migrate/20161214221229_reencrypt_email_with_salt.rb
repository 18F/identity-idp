class ReencryptEmailWithSalt < ActiveRecord::Migration
  def up
    rotate(Figaro.env.password_pepper, Figaro.env.email_encryption_key)
  end

  def down
    rotate(Figaro.env.email_encryption_key, Figaro.env.password_pepper)
  end

  def rotate(old_salt, new_salt)
    key = Figaro.env.email_encryption_key
    cost = Figaro.env.email_encryption_cost
    encryptor = Pii::PasswordEncryptor.new

    User.find_in_batches.with_index do |users, batch|
      puts "Updating batch #{batch}"
      users.each do |user|
        begin
          old_uak = UserAccessKey.new(password: key, salt: old_salt, cost: cost)
          new_uak = UserAccessKey.new(password: key, salt: new_salt, cost: cost)
          plain_email = encryptor.decrypt(user.encrypted_email, old_uak)
          ee = EncryptedEmail.new_from_email(plain_email, new_uak)
          user.update_columns(encrypted_email: ee.encrypted, email_encryption_cost: cost)
        rescue Pii::EncryptionError => err 
          puts "Skipping #{user.id} - error rotating encrypted email: #{err}"
        end
      end
    end
  end
end
