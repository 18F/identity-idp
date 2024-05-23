# frozen_string_literal: true

require 'digest'

class BackupCodeGenerator
  attr_reader :num_words

  NUMBER_OF_CODES = 10

  def initialize(user, num_words: BackupCodeConfiguration::NUM_WORDS)
    @num_words = num_words
    @user = user
  end

  def delete_and_regenerate(salt: SecureRandom.hex(32))
    codes = generate_new_codes

    BackupCodeConfiguration.transaction do
      @user.backup_code_configurations.destroy_all
      codes.each { |code| save_code(code: code, salt: salt) }
    end

    codes
  end

  # @return [Boolean]
  def verify(plaintext_code)
    if_valid_consume_code_return_config(plaintext_code).present?
  end

  # @return [BackupCodeConfiguration, nil]
  def if_valid_consume_code_return_config(plaintext_code)
    return unless plaintext_code.present?
    backup_code = RandomPhrase.normalize(plaintext_code)
    config = BackupCodeConfiguration.find_with_code(code: backup_code, user_id: @user.id)
    return unless code_usable?(config)
    config.update!(used_at: Time.zone.now)
    config
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
