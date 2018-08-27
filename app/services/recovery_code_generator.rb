class RecoveryCodeGenerator
  attr_reader :user_access_key, :length

  INVALID_CODE = 'meaningless string that RandomPhrase will never generate'.freeze

  def initialize(user, length: 6, split: 2)
    @length = length
    @split = split
    @user = user
  end

  def generate
    delete_existing_codes
    generate_new_codes
  end

  def verify(plaintext_code)
    user.valid_recovery_code(normalize(plaintext_code))
  end

  private

  attr_reader :user

  def save_code(code)
    rc = RecoveryCode.new
    rc.code = code
    rc.user_id = @user.id
    rc.used = 0
    rc.save
  end

  def delete_existing_codes
    RecoveryCode.find_each(:user_id => user.id) do |rc|
      rc.remove
    end
  end

  def generate_new_codes
    (0..9).each do
      code = recovery_code
      save_code(code)
    end
  end

  def encode_code(code)
    decoded = Base32::Crockford.decode(code)
    Base32::Crockford.encode(decoded, length: @length, split: @split).tr('-', ' ')
  end

  def normalize(plaintext_code)
    normed = plaintext_code.gsub(/\W/, '')
    split_length = @split || RandomPhrase::WORD_LENGTH
    normed_length = normed.length
    return INVALID_CODE unless normed_length == personal_key_length * split_length
    encode_code(code: normed, length: normed_length, split: split_length)
  rescue ArgumentError, RegexpError
    INVALID_CODE
  end

  def recovery_code
    c = SecureRandom.hex
    raw = c[1, @split * @length]
    normalize(raw)
  end

  def personal_key_length
    Figaro.env.recovery_code_length.to_i || length
  end
end