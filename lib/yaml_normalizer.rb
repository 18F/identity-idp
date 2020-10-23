require 'yaml'
require 'active_support/core_ext/object/try'

module YamlNormalizer
  module_function

  # Reads in YAML at a path, trims whitespace from each key, and writes it back to the file
  def run(argv)
    argv.each do |file|
      warn file
      data = YAML.load_file(file)
      handle_hash(data)
      dump(file, data)
    end
  end

  def normalize(hash)
    handle_hash(hash)
  end

  def dump(file, data)
    File.open(file, 'w') { |io| io.puts YAML.dump(data) }
  end

  def handle_hash(hash)
    copy = hash.each_value { |value| handle_value(value) }.dup
    hash.clear
    copy.keys.sort.each do |key|
      hash[key] = copy[key]
    end
    hash
  end

  def handle_array(array)
    array.each { |value| handle_value(value) }
  end

  def handle_value(value)
    if value.is_a?(String)
      trim(value)
    elsif value.is_a?(Array)
      handle_array(value)
    elsif value.is_a?(Hash)
      handle_hash(value)
    elsif value && value != true && value != false
      raise ArgumentError, "unknown YAML value #{value}"
    end
  end

  def trim(str)
    str.sub!(/\A\n+/, '')
    ended_with_space_after_colon = str =~ /: \s*\Z/
    str.rstrip!
    str << ' ' if ended_with_space_after_colon
  end
end
