class SessionEncryptor
  def initialize
    @initialized_user_access_key = nil
    @encryption_user_access_key = nil
    @decryption_user_access_key_map = {}
  end

  def load(value)
    user_access_key = decryption_user_access_key(value)
    decrypted = encryptor.decrypt(value, user_access_key)
    JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
  end

  def dump(value)
    plain = JSON.generate(value, quirks_mode: true)
    encryptor.encrypt(plain, encryption_user_access_key)
  end

  def initialized_user_access_key
    # Initialize access key once and share it since scrypt hashes take a long time to calculate
    # Return a dupe since encryption operations mutate this key
    return @initialized_user_access_key.dup if @initialized_user_access_key.is_a?(UserAccessKey)

    key = Figaro.env.session_encryption_key
    @initialized_user_access_key = UserAccessKey.new(password: key, salt: key)
  end

  private

  attr_reader :decryption_user_access_key_map

  def decryption_user_access_key(encrypted_value)
    encryption_key = encrypted_value.split('.').first
    existing_user_access_key = decryption_user_access_key_map[encryption_key]
    return existing_user_access_key if existing_user_access_key.is_a?(UserAccessKey)

    decryption_user_access_key_map[encryption_key] = initialized_user_access_key
  end

  def encryption_user_access_key
    return @encryption_user_access_key if @encryption_user_access_key.is_a?(UserAccessKey)
    @encryption_user_access_key ||= initialized_user_access_key
  end

  def encryptor
    Pii::PasswordEncryptor.new
  end
end
