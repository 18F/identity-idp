# frozen_string_literal: true

class PersonalKeyFormatter
  CHAR_COUNT = RandomPhrase::WORD_LENGTH
  WORD_COUNT = IdentityConfig.store.recovery_code_length
  VALID_CHAR = '[a-zA-Z0-9]'
  VALID_WORD = "#{VALID_CHAR}{#{CHAR_COUNT}}".freeze
  REGEXP_STRING = "(?:#{VALID_WORD}([\\s\\-])?){#{WORD_COUNT - 1}}#{VALID_WORD}".freeze
  REGEXP = /\A#{REGEXP_STRING}\Z/o
  CODE_LENGTH = CHAR_COUNT * WORD_COUNT + (WORD_COUNT - 1)

  def self.regexp
    REGEXP
  end

  def self.regexp_string
    REGEXP_STRING
  end

  def self.code_length
    CODE_LENGTH
  end
end
