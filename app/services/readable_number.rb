# frozen_string_literal: true

class ReadableNumber
  FORCED_NUMERIC_LOCALES = %i[zh].to_set.freeze

  MAX_NUMBER_TO_SPELL_OUT = 10

  # Returns a number as it would expected to be used in a sentence
  # @param number [Integer] Number to transform to readable form
  # @return [String] Number in readable form
  def self.of(number)
    readable_number = catch(:use_number) do
      throw :use_number if FORCED_NUMERIC_LOCALES.include?(I18n.locale)
      throw :use_number if number > MAX_NUMBER_TO_SPELL_OUT
      throw :use_number if !NumbersAndWords::I18n.languages.include?(I18n.locale)
      number.to_words
    end

    readable_number || number.to_s
  end
end
