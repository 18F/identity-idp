require 'i18n'
require 'json'

# Custom i18n backend that parse our "flat_yml" files into the nested
# hash structure that i18n works with
class I18nTxtBackend < I18n::Backend::Simple
  # @param filename [String] filename, assumed to have the locale slug in the filename such as "en.txt"
  # @return [Array(Hash, Boolean)] tuple of a hash and keys_symbolized
  def load_txt(filename)
    locale = File.basename(filename, '.txt')

    [
      {
        locale => unflatten(File.readlines(filename, chomp: true))
      },
      false,
    ]
  end

  # @param [Array<String>] lines
  # @return [Array(Hash, Boolean)] tuple of a hash and keys_symbolized
  def unflatten(lines)
    result = {}

    lines.each do |line|
      full_key, value_str = line.split(':', 2)
      value = JSON.parse(value_str)


      key_parts = full_key.split('.')
      last = key_parts.last

      to_insert = result

      key_parts.each_cons(2) do |key_part, next_part|
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
