require 'digest'

class BackupCodeGenerator
  attr_reader :num_words

  NUMBER_OF_CODES = 10

  def initialize(user, num_words: BackupCodeConfiguration::NUM_WORDS)
    @num_words = num_words
    @user = user
  end

  # @return [Array<String>]
  def generate
    delete_existing_codes
    generate_new_codes
  end

  # @return [Array<String>]
  def create
    @user.save
    save(generate)
  end

  # @return [Boolean]
  def verify(plaintext_code)
    backup_code = RandomPhrase.normalize(plaintext_code)
    code = BackupCodeConfiguration.find_with_code(code: backup_code, user_id: @user.id)
    return unless code_usable?(code)
    code.update!(used_at: Time.zone.now)
    true
  end

  def delete_existing_codes
    @user.backup_code_configurations.destroy_all
  end

  # @return [Array<String>]
  def save(codes, salt: SecureRandom.hex(32))
    delete_existing_codes
    codes.each { |code| save_code(code: code, salt: salt) }
  end

  private

  def generate_new_codes
    while result.length < NUMBER_OF_CODES
      code = backup_code
      result << code unless result.include?(code)
    end
    result
  end

  def code_usable?(code)
    code && code.used_at.nil?
  end

  def save_code(code:, salt:)
    @user.backup_code_configurations.create!(
      code_salt: salt,
      code_cost: cost,
      code: code,
    )
  end

  def backup_code
    RandomPhrase.new(num_words: num_words, separator: nil).to_s
  end

  def result
    @result ||= []
  end

  def cost
    IdentityConfig.store.backup_code_cost
  end
end
