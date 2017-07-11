require 'yaml'
require 'active_support/core_ext/object/try'

class YamlNormalizer
  # Reads in YAML at a path, trims whitespace from each key, and writes it back to the file
  def self.run(argv)
    argv.each do |file|
      $stderr.puts file
      data = YAML.load_file(file)
      chomp_each(data)
      dump(file, data)
    end
  end

  def self.chomp_each(hash)
    hash.each do |_key, value|
      if value.is_a?(String)
        trim(value)
      elsif value.is_a?(Array)
        strip_array(value)
      else
        chomp_each(value)
      end
    end
  end

  def self.dump(file, data)
    File.open(file, 'w') { |io| io.puts YAML.dump(data) }
  end

  def self.strip_array(value)
    value.each { |str| trim(str) if str }
  end

  def self.trim(str)
    ended_with_space_after_colon = str =~ /: \s*\Z/
    str.rstrip!
    str << ' ' if ended_with_space_after_colon
  end
end
