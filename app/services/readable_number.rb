# frozen_string_literal: true

class ReadableNumber
  FORCED_NUMERIC_LOCALES = %i[zh].to_set.freeze

  MAX_NUMBER_TO_SPELL_OUT = 10

  # Returns a number as it would expected to be used in a sentence
  # @param number [Integer] Number to transform to readable form
  # @return [String] Number in readable form
  def self.of(number)
    if FORCED_NUMERIC_LOCALES.include?(I18n.locale) ||
       number > MAX_NUMBER_TO_SPELL_OUT ||
       !NumbersAndWords::I18n.languages.include?(I18n.locale)
      number.to_s
    else
      number.to_words
    end
  end
end
