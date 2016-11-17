class SessionEncryptor
  def self.build_user_access_key
    env = Figaro.env
    UserAccessKey.new(env.session_encryption_key, env.password_pepper)
  end

  cattr_reader :user_access_key do
    build_user_access_key
  end

  def self.load(value)
    decrypted = encryptor.decrypt(value, user_access_key)
    Marshal.load(::Base64.decode64(decrypted))
  end

  def self.dump(value)
    plain = ::Base64.encode64(Marshal.dump(value))
    encryptor.encrypt(plain, user_access_key)
  end

  def self.encryptor
    Pii::PasswordEncryptor.new
  end
end
