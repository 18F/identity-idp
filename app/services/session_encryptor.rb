class SessionEncryptor
  @user_access_key = nil

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

  def self.user_access_key
    @user_access_key ||= UserAccessKey.new(env.session_encryption_key, env.password_pepper)
  end

  def self.env
    Figaro.env
  end
  private_class_method :env
end
