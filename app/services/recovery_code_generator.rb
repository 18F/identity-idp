require 'digest'

class RecoveryCodeGenerator
  attr_reader :user_access_key, :length

  INVALID_CODE = 'meaningless string that RandomPhrase will never generate'.freeze

  def initialize(user, length: 2, split: 4)
    @length = length
    @split = split
    @user = user
  end

  def generate
    delete_existing_codes
    generate_new_codes
  end

  def verify(plaintext_code)
    # code = encrypt( plaintext_code )
    puts "*********************** #{plaintext_code}"
    recovery_code = normalize(plaintext_code)
    code = @user.recovery_code_configurations.find_by code: recovery_code
    return false if code.nil?
    code.update!(used: true, used_at: Time.zone.now)
    true
  end

  private

  def encrypt(plaintext)
    plaintext
  end

  def save_code(code)
    rc = RecoveryCodeConfiguration.new
    rc.code = code
    rc.user_id = @user.id
    rc.used = false
    rc.save
  end

  def delete_existing_codes
    @user.recovery_code_configurations.destroy_all
  end

  def generate_new_codes
    result = []
    (0..9).each do
      code = recovery_code
      result.push code
      save_code(code)
    end
    result
  end

  def encode_code(code:, length:, split:)
    decoded = Base32::Crockford.decode(code)
    Base32::Crockford.encode(decoded, length: length, split: split).tr('-', ' ')
  end

  def normalize(plaintext_code)
    normed = plaintext_code.gsub(/\W/, '')
    #split_length = @split
    #normed_length = normed.length
    #return INVALID_CODE unless normed_length == @length * split_length
    #encode_code(code: normed, length: normed_length, split: split_length)
  #rescue ArgumentError, RegexpError
   # INVALID_CODE
  end

  def recovery_code
    c = SecureRandom.hex
    raw = c[1, @split * @length]
    normalize(raw)
  end
end
