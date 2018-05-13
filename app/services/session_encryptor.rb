class SessionEncryptor
  def initialize
    @user_access_key = reload_user_access_key
  end

  def duped_user_access_key
    # Reload if UserAccessKey constant has been reloaded
    @user_access_key = reload_user_access_key if should_reload_user_access_key

    # Return a clone since encryptor.decrypt mutates this key
    @user_access_key.dup
  end

  def load(value)
    decrypted = encryptor.decrypt(value, duped_user_access_key)

    JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
  end

  def dump(value)
    plain = JSON.generate(value, quirks_mode: true)
    encryptor.encrypt(plain, duped_user_access_key)
  end

  private

  def encryptor
    Pii::PasswordEncryptor.new
  end

  def reload_user_access_key
    key = Figaro.env.session_encryption_key
    Encryption::UserAccessKey.new(password: key, salt: key)
  end

  def should_reload_user_access_key
    !@user_access_key.is_a? Encryption::UserAccessKey
  end
end
