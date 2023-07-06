# frozen_string_literal: true

require 'rails_helper'
require 'i18n/tasks'

# List of keys allowed to contain different interpolation arguments across locales
ALLOWED_INTERPOLATION_MISMATCH_KEYS = [
  'time.formats.event_timestamp_js',
]

module I18n
  module Tasks
    class BaseTask
      # List of keys allowed to be untranslated or are the same as English
      ALLOWED_UNTRANSLATED_KEYS = [
        { key: 'account.navigation.menu', locales: %i[fr] }, # "Menu" is "Menu" in French
        { key: 'doc_auth.headings.photo', locales: %i[fr] }, # "Photo" is "Photo" in French
        { key: /^i18n\.locale\./ }, # Show locale options translated as that language
        { key: /^i18n\.transliterate\./ }, # Approximate non-ASCII characters in ASCII
        { key: /^countries/ }, # Some countries have the same name across languages
        { key: 'links.contact', locales: %i[fr] }, # "Contact" is "Contact" in French
        { key: 'simple_form.no', locales: %i[es] }, # "No" is "No" in Spanish
        { key: 'simple_form.required.html' }, # No text content
        { key: 'simple_form.required.mark' }, # No text content
        { key: 'time.am' }, # "AM" is "AM" in French and Spanish
        { key: 'time.pm' }, # "PM" is "PM" in French and Spanish
        { key: 'datetime.dotiw.minutes.one' }, # "minute is minute" in French and English
        { key: 'datetime.dotiw.minutes.other' }, # "minute is minute" in French and English
        { key: 'mailer.logo' }, # "logo is logo" in English, French and Spanish
      ].freeze

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
          next if allowed_untranslated_key?(current_locale, key)
          node.value == base_locale_value
        end
      end

      def allowed_untranslated_key?(locale, key)
        ALLOWED_UNTRANSLATED_KEYS.any? do |entry|
          next unless key&.match?(Regexp.new(entry[:key]))
          !entry.key?(:locales) || entry[:locales].include?(locale.to_sym)
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

  it 'does not have missing keys' do
    expect(missing_keys).to(
      be_empty,
      "Missing #{missing_keys.leaves.count} i18n keys, run `i18n-tasks missing' to show them",
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
  end

  it 'does not have keys with missing interpolation arguments (check callsites for correct args)' do
    missing_interpolation_argument_keys = []

    i18n.data[i18n.base_locale].select_keys do |key, _node|
      if key.start_with?('i18n.transliterate.rule.') || i18n.t(key).is_a?(Array) || i18n.t(key).nil?
        next
      end

      interpolation_arguments = i18n.locales.map do |locale|
        extract_interpolation_arguments i18n.t(key, locale)
      end.compact

      missing_interpolation_argument_keys.push(key) if interpolation_arguments.uniq.length > 1
    end

    missing_interpolation_argument_keys -= ALLOWED_INTERPOLATION_MISMATCH_KEYS

    expect(missing_interpolation_argument_keys).to be_empty
  end

  root_dir = File.expand_path(File.join(File.dirname(__FILE__), '../'))

  Dir[File.join(root_dir, '/config/locales/**')].sort.each do |group_path|
    i18n_group = group_path.sub("#{root_dir}/", '')

    describe i18n_group do
      it 'has HTML inside at least one locale string for all keys with .html or _html ' do
        combined = Hash.new { |h, k| h[k] = {} }

        Dir["#{group_path}/**.yml"].each do |file|
          locale, data = YAML.load_file(file).first
          flatten_hash(data).each do |key, str|
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

    Dir["#{group_path}/*.yml"].each do |full_path|
      i18n_file = full_path.sub("#{root_dir}/", '')

      describe i18n_file do
        # Transliteration includes special characters by definition, so it could fail checks below
        if !full_path.match?(%(/config/locales/transliterate/))
          it 'has only lower_snake_case keys' do
            keys = flatten_hash(YAML.load_file(full_path)).keys

            bad_keys = keys.reject { |key| key =~ /^[a-z0-9_.]+$/ }

            expect(bad_keys).to be_empty
          end

          it 'has only has XML-safe identifiers (keys start with a letter)' do
            keys = flatten_hash(YAML.load_file(full_path)).keys

            bad_keys = keys.select { |key| key.split('.').any? { |part| part =~ /^[0-9]/ } }

            expect(bad_keys).to be_empty
          end
        end

        it 'has correctly-formatted interpolation values' do
          bad_keys = flatten_hash(YAML.load_file(full_path)).select do |_key, value|
            next unless value.is_a?(String)

            interpolation_names = value.scan(/%\{([^}]+)\}/).flatten

            interpolation_names.any? { |name| name.downcase != name }
          end

          expect(bad_keys).to be_empty
        end

        it 'does not contain any translations expecting legacy fallback behavior' do
          bad_keys = flatten_hash(YAML.load_file(full_path)).select do |_key, value|
            value.include?('NOT TRANSLATED YET')
          end

          expect(bad_keys).to be_empty
        end

        it 'does not contain any translations that hardcode APP_NAME' do
          bad_keys = flatten_hash(YAML.load_file(full_path)).select do |_key, value|
            value.include?(APP_NAME)
          end

          expect(bad_keys).to be_empty
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
      key =~ /html/
    end
  end

  def extract_interpolation_arguments(translation)
    translation.scan(I18n::INTERPOLATION_PATTERN).
      map(&:compact).map(&:first).to_set
  end

  def flatten_hash(hash, parent_keys: [], out_hash: {}, &block)
    hash.each do |key, value|
      if value.is_a?(Hash)
        flatten_hash(value, parent_keys: parent_keys + [key], out_hash: out_hash, &block)
      else
        flat_key = [*parent_keys, key].join('.')
        out_hash[flat_key] = value
      end
    end

    out_hash
  end
end
