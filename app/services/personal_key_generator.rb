class PersonalKeyGenerator
  attr_reader :user_access_key, :length

  INVALID_CODE = 'meaningless string that RandomPhrase will never generate'.freeze

  def initialize(user, length: 4)
    @user = user
    @length = length
  end

  def create
    user.personal_key = raw_personal_key
    user.save!
    raw_personal_key.tr(' ', '-')
  end

  def verify(plaintext_code)
    user.valid_personal_key?(normalize(plaintext_code))
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
