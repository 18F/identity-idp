class RecoveryCodeGenerator
  attr_reader :user_access_key

  def initialize(user, length: 16)
    @user = user
    @length = length
    @key_maker = EncryptedKeyMaker.new
  end

  def create
    salt = Devise.friendly_token[0, 20]
    @user_access_key = make_user_access_key(raw_recovery_code, salt)

    user.update!(recovery_code: hashed_code, recovery_salt: salt)

    raw_recovery_code
  end

  def verify(plaintext_code)
    @user_access_key = make_user_access_key(plaintext_code, user.recovery_salt)
    encryption_key, encrypted_code = user.recovery_code.split(Pii::Encryptor::DELIMITER)
    begin
      key_maker.unlock(user_access_key, encryption_key)
    rescue Pii::EncryptionError => _err
      return false
    end
    Devise.secure_compare(encrypted_code, user_access_key.encrypted_password)
  end

  private

  attr_reader :length, :user, :key_maker

  def make_user_access_key(code, salt)
    UserAccessKey.new(code, salt)
  end

  def hashed_code
    key_maker.make(user_access_key)
    [
      user_access_key.encryption_key,
      user_access_key.encrypted_password
    ].join(Pii::Encryptor::DELIMITER)
  end

  def raw_recovery_code
    @raw_recovery_code ||= SecureRandom.hex(recovery_code_length / 2)
  end

  def recovery_code_length
    Figaro.env.recovery_code_length.to_i || length
  end
end
