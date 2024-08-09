module I18n
  class << self
    prepend(
      Module.new do
        def t(*args, ignore_test_helper_missing_interpolation: false, **kwargs)
          result = super(*args, **kwargs)
          return result if ignore_test_helper_missing_interpolation || !result.include?('%{')
          raise "Missing interpolation in translated string: #{result}"
        end
      end,
    )
  end

  # List of keys allowed to contain different interpolation arguments across locales
  ALLOWED_INTERPOLATION_MISMATCH_KEYS = [
    'time.formats.event_timestamp_js',
  ].freeze

  ALLOWED_LEADING_OR_TRAILING_SPACE_KEYS = [
    'datetime.dotiw.last_word_connector',
    'datetime.dotiw.two_words_connector',
    'datetime.dotiw.words_connector',
  ].sort.freeze

  # These are keys with mismatch interpolation for specific locales
  ALLOWED_INTERPOLATION_MISMATCH_LOCALE_KEYS = [].freeze

  PUNCTUATION_PAIRS = {
    '{' => '}',
    '[' => ']',
    '(' => ')',
    '<' => '>',
    '（' => '）',
    '“' => '”',
  }.freeze

  # A set of patterns which are expected to only occur within specific locales. This is an imperfect
  # solution based on current content, intended to help prevent accidents when adding new translated
  # content. If you are having issues with new content, it would be reasonable to remove or modify
  # the parts of the pattern which are valid for the content you're adding.
  LOCALE_SPECIFIC_CONTENT = {
    fr: / [nd]’|à/i,
    es: /¿|ó/,
  }.freeze

  # Regex patterns for commonly misspelled words by locale. Match on word boundaries ignoring case.
  # The current design should be adequate for a small number of words in each language.
  # If we encounter false positives we should come up with a scheme to ignore those cases.
  # Add additional words using the regex union operator '|'.
  COMMONLY_MISSPELLED_WORDS = {
    en: /\b(cancelled|occured|seperated?)\b/i,
  }.freeze

  module Tasks
    class BaseTask
      # List of keys allowed to be untranslated or are the same as English
      # rubocop:disable Layout/LineLength
      ALLOWED_UNTRANSLATED_KEYS = [
        { key: 'i18n.locale.en', locales: %i[es fr zh] },
        { key: 'i18n.locale.es', locales: %i[es fr zh] },
        { key: 'i18n.locale.fr', locales: %i[es fr zh] },
        { key: 'i18n.locale.zh', locales: %i[es fr zh] },
        { key: 'account.email_language.name.en', locales: %i[es fr zh] },
        { key: 'account.email_language.name.es', locales: %i[es fr zh] },
        { key: 'account.email_language.name.fr', locales: %i[es fr zh] },
        { key: 'account.email_language.name.zh', locales: %i[es fr zh] },
        { key: 'account.navigation.menu', locales: %i[fr] }, # "Menu" is "Menu" in French
        { key: /^countries/ }, # Some countries have the same name across languages
        { key: 'date.formats.long', locales: %i[es zh] },
        { key: 'date.formats.short', locales: %i[es zh] },
        { key: 'datetime.dotiw.minutes.one' }, # "minute is minute" in French and English
        { key: 'datetime.dotiw.minutes.other' }, # "minute is minute" in French and English
        { key: 'datetime.dotiw.words_connector' }, # " , " is only punctuation and not translated
        { key: 'in_person_proofing.process.eipp_bring_id.image_alt_text', locales: %i[fr es zh] }, # Real ID is considered a proper noun in this context, ID translated to ID Card in Chinese
        { key: 'links.contact', locales: %i[fr] }, # "Contact" is "Contact" in French
        { key: 'saml_idp.auth.error.title', locales: %i[es] }, # "Error" is "Error" in Spanish
        { key: 'simple_form.no', locales: %i[es] }, # "No" is "No" in Spanish
        { key: 'telephony.format_length.six', locales: %i[zh] }, # numeral is not translated
        { key: 'telephony.format_length.ten', locales: %i[zh] }, # numeral is not translated
        { key: 'time.formats.event_date', locales: %i[es zh] },
        { key: 'time.formats.event_time', locales: %i[es zh] },
        { key: 'time.formats.event_timestamp', locales: %i[zh] },
        { key: 'time.formats.full_date', locales: %i[es] }, # format is the same in Spanish and English
        { key: 'time.formats.sms_date' }, # for us date format
      ].freeze
      # rubocop:enable Layout/LineLength

      def leading_or_trailing_whitespace_keys
        self.locales.each_with_object([]) do |locale, result|
          data[locale].key_values.each_with_object(result) do |key_value, result|
            key, value = key_value
            next if ALLOWED_LEADING_OR_TRAILING_SPACE_KEYS.include?(key)

            leading_or_trailing_whitespace =
              if value.is_a?(String)
                leading_or_trailing_whitespace?(value)
              elsif value.is_a?(Array)
                value.compact.any? { |x| leading_or_trailing_whitespace?(x) }
              end

            if leading_or_trailing_whitespace
              result << "#{locale}.#{key}"
            end

            result
          end
        end
      end

      def leading_or_trailing_whitespace?(value)
        value.match?(/\A\s|\s\z/)
      end

      def untranslated_keys
        data[base_locale].key_values.each_with_object([]) do |key_value, result|
          key, value = key_value

          result << key if untranslated_key?(key, value)
          result
        end
      end

      def untranslated_key?(key, base_locale_value)
        locales = self.locales - [base_locale]
        locales.any? do |current_locale|
          node = data[current_locale].first.children[key]
          next unless node&.value&.is_a?(String)
          next if node.value.empty?
          next unless node.value == base_locale_value
          true unless allowed_untranslated_key?(current_locale, key)
        end
      end

      def allowed_untranslated_key?(locale, key)
        ALLOWED_UNTRANSLATED_KEYS.any? do |entry|
          next if entry[:key].is_a?(Regexp) && !key.match?(entry[:key])
          next if entry[:key].is_a?(String) && key != entry[:key]

          if !entry.key?(:locales) || entry[:locales].include?(locale.to_sym)
            entry[:used] = true

            true
          end
        end
      end
    end
  end
end
