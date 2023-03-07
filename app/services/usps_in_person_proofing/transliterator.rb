module UspsInPersonProofing
  class Transliterator
    # This is the default. May not be able to override this in current version.
    REPLACEMENT = '?'.freeze

    # Container to hold the results of transliteration
    TransliterationResult = Struct.new(
      # Was the value different after transliteration?
      :changed?,
      # Original value submtted for transliteration
      :original,
      # Transliterated value
      :transliterated,
      # Characters from the original that could not be transliterated
      :unsupported_chars,
      keyword_init: true,
    )

    # Transliterate values for usage in the USPS API. This will additionally strip/reduce
    # excess whitespace and check for special characters that are unsupported by transliteration.
    # Additional validation may be necessary depending on the specific field being transliterated.
    #
    # @param [String,#to_s] value The value to transliterate for USPS
    # @return [TransliterationResult] The transliterated value
    def transliterate(value)
      stripped = value.to_s.gsub(/\s+/, ' ').strip
      transliterated = I18n.transliterate(stripped, locale: :en)

      unsupported_chars = []
      unless stripped.count(REPLACEMENT) == transliterated.count(REPLACEMENT)
        transliterated.chars.zip(stripped.chars).each do |val, stripped|
          if val == REPLACEMENT && stripped != REPLACEMENT
            unsupported_chars.append(stripped)
          end
        end
      end

      # Using struct instead of exception here to reduce likelihood of logging PII
      TransliterationResult.new(
        changed?: value != transliterated,
        original: value,
        transliterated: transliterated,
        unsupported_chars: unsupported_chars,
      )
    end
  end
end
