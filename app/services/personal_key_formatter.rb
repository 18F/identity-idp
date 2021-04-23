class PersonalKeyFormatter
  CHAR_COUNT = RandomPhrase::WORD_LENGTH
  WORD_COUNT = IdentityConfig.store.recovery_code_length
  VALID_CHAR = '[a-zA-Z0-9]'.freeze
  VALID_WORD = "#{VALID_CHAR}{#{CHAR_COUNT}}".freeze
  REGEXP = "(?:#{VALID_WORD}([\s-])?){#{WORD_COUNT - 1}}#{VALID_WORD}".freeze

  def self.regexp
    /\A#{REGEXP}\Z/
  end

  def self.regexp_string
    REGEXP
  end

  def self.code_length
    CHAR_COUNT * WORD_COUNT + (WORD_COUNT - 1)
  end
end
