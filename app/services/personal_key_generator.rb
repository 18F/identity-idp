class PersonalKeyGenerator
  attr_reader :user_access_key, :length

  INVALID_CODE = 'meaningless string that RandomPhrase will never generate'.freeze

  def initialize(user, length: 4)
    @user = user
    @length = length
  end

  def create
    digest = create_encrypted_recovery_code_digest
    # Until we drop the old columns, still write to them so that we can rollback
    create_legacy_recovery_code(digest)
    user.save!
    raw_personal_key.tr(' ', '-')
  end

  def verify(plaintext_code)
    Encryption::PasswordVerifier.verify(
      password: normalize(plaintext_code),
      digest: user.encrypted_recovery_code_digest
    )
  end

  def normalize(plaintext_code)
    normed = plaintext_code.gsub(/\W/, '')
    split_length = RandomPhrase::WORD_LENGTH
    normed_length = normed.length
    return INVALID_CODE unless normed_length == personal_key_length * split_length
    encode_code(code: normed, length: normed_length, split: split_length)
  rescue ArgumentError, RegexpError
    INVALID_CODE
  end

  private

  attr_reader :user

  def create_legacy_recovery_code(digest)
    user.personal_key = [
      digest.encryption_key,
      digest.encrypted_password,
    ].join(Encryption::Encryptors::AesEncryptor::DELIMITER)
    user.recovery_salt = digest.password_salt
    user.recovery_cost = digest.password_cost
  end

  def create_encrypted_recovery_code_digest
    digest = Encryption::PasswordVerifier.digest(raw_personal_key)
    user.encrypted_recovery_code_digest = digest.to_s
    digest
  end

  def encode_code(code:, length:, split:)
    decoded = Base32::Crockford.decode(code)
    Base32::Crockford.encode(decoded, length: length, split: split).tr('-', ' ')
  end

  def raw_personal_key
    @raw_personal_key ||= RandomPhrase.new(num_words: personal_key_length).to_s
  end

  def personal_key_length
    Figaro.env.recovery_code_length.to_i || length
  end
end
