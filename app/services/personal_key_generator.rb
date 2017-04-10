class PersonalKeyGenerator
  attr_reader :user_access_key, :length

  INVALID_CODE = 'meaningless string that RandomPhrase will never generate'.freeze

  def initialize(user, length: 4)
    @user = user
    @length = length
    @key_maker = EncryptedKeyMaker.new
  end

  def create
    user.recovery_salt = Devise.friendly_token[0, 20]
    user.recovery_cost = Figaro.env.scrypt_cost
    @user_access_key = make_user_access_key(raw_personal_key)
    user.personal_key = hashed_code
    user.save!
    raw_personal_key.tr(' ', '-')
  end

  def verify(plaintext_code)
    @user_access_key = make_user_access_key(normalized_code(plaintext_code))
    encryption_key, encrypted_code = user.personal_key.split(Pii::Encryptor::DELIMITER)
    begin
      key_maker.unlock(user_access_key, encryption_key)
    rescue Pii::EncryptionError => _err
      return false
    end
    Devise.secure_compare(encrypted_code, user_access_key.encrypted_password)
  end

  def normalized_code(plaintext_code)
    normed = plaintext_code.gsub(/\W/, '')
    split_length = normed.length / length
    decoded = Base32::Crockford.decode(normed)
    Base32::Crockford.encode(decoded, length: 16, split: split_length).tr('-', ' ')
  rescue ArgumentError, RegexpError
    INVALID_CODE
  end

  private

  attr_reader :user, :key_maker

  def make_user_access_key(code)
    UserAccessKey.new(password: code, salt: user.recovery_salt, cost: user.recovery_cost)
  end

  def hashed_code
    key_maker.make(user_access_key)
    [
      user_access_key.encryption_key,
      user_access_key.encrypted_password,
    ].join(Pii::Encryptor::DELIMITER)
  end

  def raw_personal_key
    @raw_personal_key ||= RandomPhrase.new(num_words: personal_key_length).to_s
  end

  def personal_key_length
    Figaro.env.recovery_code_length.to_i || length
  end
end
