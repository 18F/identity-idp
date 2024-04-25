require 'i18n'
require 'json'

# Custom i18n backend that parse our "flat_yml" files into the nested
# hash structure that i18n works with
class I18nFlatYmlBackend < I18n::Backend::Simple
  # @param filename [String] filename, assumed to have the locale slug in the filename such as "en.txt"
  # @return [Array(Hash, Boolean)] tuple of a hash and keys_symbolized
  def load_yml(filename)
    content, keys_symbolized = super

    if content.is_a?(Hash) && content.keys.size == 1 && content[content.keys.first].is_a?(Hash)
      # Nested .yml
      [content, keys_symbolized]
    else
      # Flattened .yml
      locale = File.basename(filename, '.yml')

      [
        {
          locale => unflatten(content)
        },
        false,
      ]
    end
  end

  # @param [Hash<String, String>] key_values
  # @return [Hash<String, Hash<String, String>>]
  def unflatten(key_values)
    result = {}

    key_values.each do |full_key, value|
      *key_parts, last = full_key.to_s.split('.')

      to_insert = result

      key_parts.each do |key_part|
        to_insert = (to_insert[key_part] ||= {})
      end

      to_insert[last] = value
    end

    convert_arrays(result)
  end

  # If all keys of a hash are numeric, converts the hash to an array
  def convert_arrays(outer)
    outer.transform_values do |inner|
      if inner.is_a?(Hash)
        if inner.keys.all? { |key| numeric_key?(key) }
          inner.to_a.sort_by { |k, _v| k.to_i }.map { |_k, v| v }
        else
          convert_arrays(inner)
        end
      else
        inner
      end
    end
  end

  def numeric_key?(str)
    /\A\d+\Z/.match?(str)
  end
end
