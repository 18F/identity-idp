class SessionEncryptor
  def self.build_user_access_key
    key = Figaro.env.session_encryption_key
    UserAccessKey.new(password: key, salt: key)
  end

  cattr_reader :user_access_key do
    build_user_access_key
  end

  def self.load(value)
    decrypted = encryptor.decrypt(value, user_access_key)

    JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
  end

  def self.dump(value)
    plain = JSON.generate(value, quirks_mode: true)
    encryptor.encrypt(plain, user_access_key)
  end

  def self.encryptor
    Pii::PasswordEncryptor.new
  end
end
