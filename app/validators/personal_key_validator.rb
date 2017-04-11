module PersonalKeyValidator
  extend ActiveSupport::Concern

  included do
    include ActiveModel::Validations::Callbacks

    before_validation :normalized_code

    attr_accessor :personal_key
    attr_reader :user

    validate :valid_personal_key?
  end

  private

  def normalized_code
    return nil if personal_key.blank?
    self.personal_key = personal_key_generator.normalize(personal_key)
  end

  def personal_key_regexp
    char_count = RandomPhrase::WORD_LENGTH
    word_count = Figaro.env.recovery_code_length.to_i
    valid_char = '[a-zA-Z0-9]'
    regexp = /
      \A
      (?:#{valid_char}{#{char_count}}([\s-])?){#{word_count - 1}}
      #{valid_char}{#{char_count}}
      \Z
    /x

    regexp
  end

  def valid_personal_key?
    return false unless normalized_code =~ personal_key_regexp
    personal_key_generator.verify(normalized_code)
  end

  def personal_key_generator
    @_personal_key_generator ||= PersonalKeyGenerator.new(user)
  end
end
