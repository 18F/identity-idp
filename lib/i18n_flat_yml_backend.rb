# frozen_string_literal: true

require 'i18n'

# Custom i18n backend that parse our "flat_yml" files into the nested
# hash structure that i18n works with
class I18nFlatYmlBackend < I18n::Backend::Simple
  # @param filename [String] filename, assumed to have the locale slug in the filename ex "en.txt"
  # @return [Array(Hash, Boolean)] tuple of a hash and keys_symbolized
  def load_yml(filename)
    content, keys_symbolized = super

    if self.class.nested_hashes?(content)
      [content, keys_symbolized]
    else
      [
        {
          self.class.locale(filename) => self.class.unflatten(content),
        },
        false,
      ]
    end
  end

  # @example
  #   locale("config/locales/fr.yml")
  #   # => "fr"
  def self.locale(filename)
    File.basename(filename, '.yml')
  end

  # @return [Boolean] true if +content+ appears to be a legacy "nested" yml file
  #   instead of a flat yml file
  def self.nested_hashes?(content)
    content.is_a?(Hash) && content.keys.size == 1 && content[content.keys.first].is_a?(Hash)
  end

  # @param [Hash<String, String>] key_values
  # @return [Hash<String, Hash<String, String>>]
  def self.unflatten(key_values)
    result = {}

    key_values.each do |full_key, value|
      *key_parts, last = full_key.to_s.split('.')

      to_insert = result

      key_parts.each do |key_part|
        to_insert = (to_insert[key_part] ||= {})
      end

      to_insert[last] = value
    end

    result
  end
end
