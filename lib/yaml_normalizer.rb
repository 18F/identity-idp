require 'yaml'
require 'active_support/core_ext/object/try'

class YamlNormalizer
  # Reads in YAML at a path, trims whitespace from each key, and writes it back to the file
  def self.run(argv)
    argv.each do |file|
      $stderr.puts file
      data = YAML.load_file(file)
      handle_hash(data)
      dump(file, data)
    end
  end

  def self.dump(file, data)
    File.open(file, 'w') { |io| io.puts YAML.dump(data) }
  end

  def self.handle_hash(hash)
    hash.each do |_key, value|
      handle_value(value)
    end
  end

  def self.handle_array(array)
    array.each { |value| handle_value(value) }
  end

  def self.handle_value(value)
    if value.is_a?(String)
      trim(value)
    elsif value.is_a?(Array)
      handle_array(value)
    elsif value.kind_of?(Hash)
      handle_hash(value)
    elsif value
      raise ArgumentError, "unknown YAML value #{value}"
    end
  end

  def self.trim(str)
    str.sub!(/\A\n+/, '')
    ended_with_space_after_colon = str =~ /: \s*\Z/
    str.rstrip!
    str << ' ' if ended_with_space_after_colon
  end
end
