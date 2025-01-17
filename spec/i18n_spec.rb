# frozen_string_literal: true

require 'rails_helper'
require 'i18n/tasks'

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

module I18n
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
        { key: 'time.formats.event_time', locales: %i[es zh] },
        { key: 'time.formats.event_timestamp', locales: %i[zh] },
        { key: 'time.formats.full_date', locales: %i[es] }, # format is the same in Spanish and English
        { key: 'time.formats.sms_date' }, # for us date format
        { key: 'webauthn_platform_recommended.cta' }, # English-only A/B test
        { key: 'webauthn_platform_recommended.description_save_time' }, # English-only A/B test
        { key: 'webauthn_platform_recommended.heading' }, # English-only A/B test
        { key: 'webauthn_platform_recommended.phishing_resistant' }, # English-only A/B test
        { key: 'webauthn_platform_recommended.skip' }, # English-only A/B test
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

RSpec.describe 'I18n' do
  let(:i18n) { I18n::Tasks::BaseTask.new }
  let(:missing_keys) { i18n.missing_keys }
  let(:unused_keys) { i18n.unused_keys }
  let(:untranslated_keys) { i18n.untranslated_keys }
  let(:leading_or_trailing_whitespace_keys) do
    i18n.leading_or_trailing_whitespace_keys
  end

  it 'has matching pairs of punctuation' do
    mismatched_punctuation_pairs = {}
    i18n.locales.each do |locale|
      i18n.data[locale].key_values.each do |key, value|
        PUNCTUATION_PAIRS.each do |item1, item2|
          Array(value).each do |value|
            next if value.nil?
            if value.count(item1) != value.count(item2)
              mismatched_punctuation_pairs["#{locale}.#{key}"] ||= []
              mismatched_punctuation_pairs["#{locale}.#{key}"].push("#{item1} #{item2}")
            end
          end
        end
      end
    end

    expect(mismatched_punctuation_pairs).to(
      be_empty,
      "keys with mismatched punctuation pairs: #{mismatched_punctuation_pairs.pretty_inspect}",
    )
  end

  it 'does not have missing keys' do
    expect(missing_keys).to(
      be_empty,
      "Missing #{missing_keys.leaves.count} i18n keys, run `i18n-tasks missing' to show them",
    )
  end

  it 'does not have leading or trailing whitespace' do
    expect(leading_or_trailing_whitespace_keys).to(
      be_empty,
      "keys with leading or trailing whitespace: #{leading_or_trailing_whitespace_keys}",
    )
  end

  it 'does not have unused keys' do
    expect(unused_keys).to(
      be_empty,
      "#{unused_keys.leaves.count} unused i18n keys, run `i18n-tasks unused' to show them",
    )
  end

  it 'does not have untranslated keys' do
    expect(untranslated_keys).to(
      be_empty,
      "untranslated i18n keys: #{untranslated_keys}",
    )

    unused_allowed_untranslated_keys =
      I18n::Tasks::BaseTask::ALLOWED_UNTRANSLATED_KEYS.reject { |key| key[:used] }
    expect(unused_allowed_untranslated_keys).to(
      be_empty,
      <<~EOS,
        ALLOWED_UNTRANSLATED_KEYS contains unused allowed untranslated i18n keys.
        The following keys can be removed from ALLOWED_UNTRANSLATED_KEYS:
        #{unused_allowed_untranslated_keys.pretty_inspect}
      EOS
    )
  end

  it 'does not have keys with missing interpolation arguments (check callsites for correct args)' do
    missing_interpolation_argument_keys = []
    missing_interpolation_argument_locale_keys = []

    i18n.data[i18n.base_locale].select_keys do |key, _node|
      if key.start_with?('i18n.transliterate.rule.') || i18n.t(key).is_a?(Array) || !i18n.t(key)
        next
      end

      interpolation_arguments = i18n.locales.map do |locale|
        value = extract_interpolation_arguments i18n.t(key, locale)
        if value
          ["#{locale}.#{key}", value]
        end
      end.compact.to_h

      next if interpolation_arguments.blank?
      next if interpolation_arguments.values.uniq.length == 1
      if ALLOWED_INTERPOLATION_MISMATCH_KEYS.include?(key)
        missing_interpolation_argument_keys.push(key)
        next
      end

      # interpolation_arguments is a hash where the keys are the locale-specific content key,
      # and values are the Set of interpolation arguments used in that key.
      #
      # We group and sort by the Set of interpolation arguments and assume the group with the
      # most common interpolation arguments is the correct one. We then take the keys
      # in the remaining groups and add them to the missing keys list.
      keys =
        interpolation_arguments.group_by { |_k, v| v }
          .sort_by { |_k, v| v.length * -1 }.drop(1)
          .flat_map { |x| x[1] }.to_h.keys

      missing_interpolation_argument_locale_keys += keys
    end

    unallowed_interpolation_mismatch_locale_keys =
      missing_interpolation_argument_locale_keys - ALLOWED_INTERPOLATION_MISMATCH_LOCALE_KEYS

    expect(unallowed_interpolation_mismatch_locale_keys).to(
      be_empty,
      <<~EOS,
        There are mismatched interpolation arguments:
        #{unallowed_interpolation_mismatch_locale_keys.pretty_inspect}
      EOS
    )

    unused_allowed_interpolation_mismatch_keys =
      ALLOWED_INTERPOLATION_MISMATCH_KEYS - missing_interpolation_argument_keys
    expect(unused_allowed_interpolation_mismatch_keys).to(
      be_empty,
      <<~EOS,
        ALLOWED_INTERPOLATION_MISMATCH_KEYS contains unused allowed interpolation mismatches.
        The following keys can be removed from ALLOWED_INTERPOLATION_MISMATCH_KEYS:
        #{unused_allowed_interpolation_mismatch_keys.pretty_inspect}
      EOS
    )

    unused_allowed_interpolation_mismatch_locale_keys =
      ALLOWED_INTERPOLATION_MISMATCH_LOCALE_KEYS - missing_interpolation_argument_locale_keys
    expect(unused_allowed_interpolation_mismatch_locale_keys).to(
      be_empty,
      <<~EOS,
        ALLOWED_INTERPOLATION_MISMATCH_LOCALE_KEYS contains unused allowed interpolation mismatches.
        The following keys can be removed from ALLOWED_INTERPOLATION_MISMATCH_LOCALE_KEYS:
        #{unused_allowed_interpolation_mismatch_locale_keys.pretty_inspect}
      EOS
    )
  end

  it 'has matching HTML tags across all locales' do
    i18n.data[i18n.base_locale].select_keys do |key, _node|
      if key.start_with?('i18n.transliterate.rule.') || i18n.t(key).is_a?(Array) || i18n.t(key).nil?
        next
      end

      html_unique_tags = i18n.locales.map { |locale| i18n.t(key, locale)&.scan(/<.+?>/) }.uniq

      expect(html_unique_tags.size).to eq(1), "HTML tag mismatch for key #{key}"
    end
  end

  root_dir = File.expand_path(File.join(File.dirname(__FILE__), '../'))

  ([File.join(root_dir, '/config/locales')] + Dir[File.join(root_dir, '/config/locales/**')])
    .sort.each do |group_path|
    i18n_group = group_path.sub("#{root_dir}/", '')

    describe i18n_group do
      it 'has HTML inside at least one locale string for all keys with .html or _html ' do
        combined = Hash.new { |h, k| h[k] = {} }

        Dir["#{group_path}/**.yml"].each do |file|
          locale = I18nFlatYmlBackend.locale(file)
          data = YAML.load_file(file)
          flatten_hash(data, flatten_arrays: false).each do |key, str|
            combined[key][locale] = str
          end
        end

        bad_keys = combined.select do |key, locales|
          next if locales.values.all?(&:blank?)

          key.include?('html') ^ contains_html?(locales.values)
        end

        expect(bad_keys).to be_empty
      end
    end
  end

  Dir[File.join(root_dir, '/config/locales/**/*.yml')].sort.each do |full_path|
    i18n_file = full_path.sub("#{root_dir}/", '')
    locale = File.basename(full_path, '.yml').to_sym

    describe i18n_file do
      let(:flattened_yaml_data) { flatten_hash(YAML.load_file(full_path)) }

      # Transliteration includes special characters by definition, so it could fail checks below
      if !full_path.match?(%(/config/locales/transliterate/))
        it 'has only lower_snake_case keys' do
          keys = flattened_yaml_data.keys

          bad_keys = keys.reject { |key| key =~ /^[a-z0-9_.]+$/ }
          expect(bad_keys).to be_empty
        end
      end

      it 'has correctly-formatted interpolation values' do
        bad_keys = flattened_yaml_data.select do |_key, value|
          next unless value.is_a?(String)

          interpolation_names = value.scan(/%\{([^}]+)\}/).flatten

          interpolation_names.any? { |name| name.downcase != name }
        end

        expect(bad_keys).to be_empty
      end

      it 'does not contain any translations expecting legacy fallback behavior' do
        bad_keys = flattened_yaml_data.select do |_key, value|
          value.include?('NOT TRANSLATED YET')
        end

        expect(bad_keys).to be_empty
      end

      it 'does not contain any translations that hardcode APP_NAME' do
        bad_keys = flattened_yaml_data.select do |_key, value|
          value.include?(APP_NAME)
        end

        expect(bad_keys).to be_empty
      end

      it 'does not contain content from another language' do
        flattened_yaml_data.each do |_key, value|
          other_locales = LOCALE_SPECIFIC_CONTENT.keys - [locale]
          expect(value).not_to match(
            Regexp.union(*LOCALE_SPECIFIC_CONTENT.slice(*other_locales).values),
          )
        end
      end

      it 'does not contain common misspellings', if: COMMONLY_MISSPELLED_WORDS.key?(locale) do
        flattened_yaml_data.each do |_key, value|
          expect(value).not_to match(COMMONLY_MISSPELLED_WORDS[locale])
        end
      end
    end
  end

  def contains_html?(value)
    Array(value).flatten.compact.any? do |str|
      html_tags?(str) || html_entities?(str) || likely_html_interpolation?(str)
    end
  end

  def html_tags?(str)
    str.scan(/<.+?>/).present?
  end

  def html_entities?(str)
    str.scan(/&[^;]+?;/).present?
  end

  def likely_html_interpolation?(str)
    str.scan(I18n::INTERPOLATION_PATTERN).flatten.compact.any? do |key|
      key.include?('html')
    end
  end

  def extract_interpolation_arguments(translation)
    translation.scan(I18n::INTERPOLATION_PATTERN)
      .map(&:compact).map(&:first).to_set
  end

  def flatten_hash(hash, flatten_arrays: true, parent_keys: [], out_hash: {})
    hash.each do |key, value|
      if value.is_a?(Hash)
        flatten_hash(value, flatten_arrays:, parent_keys: parent_keys + [key], out_hash:)
      elsif value.is_a?(Array) && flatten_arrays
        value.each_with_index do |item, idx|
          flat_key = [*parent_keys, key, idx.to_s].join('.')
          out_hash[flat_key] = item if item
        end
      else
        flat_key = [*parent_keys, key].join('.')
        out_hash[flat_key] = value if value
      end
    end

    out_hash
  end
end
