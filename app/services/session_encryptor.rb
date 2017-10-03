class SessionEncryptor
  def user_access_key
    @user_access_key ||= begin
      key = Figaro.env.session_encryption_key
      uak = UserAccessKey.new(password: key, salt: key)
      uak.random_r = OpenSSL::Digest::SHA256.digest(key)
      uak
    end
  end

  def load(value)
    decrypted = encryptor.decrypt(value, user_access_key)

    JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
  end

  def dump(value)
    plain = JSON.generate(value, quirks_mode: true)
    encryptor.encrypt(plain, user_access_key)
  end

  private

  def encryptor
    Pii::PasswordEncryptor.new
  end
end
