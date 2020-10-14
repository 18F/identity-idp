require 'yaml'
require 'erb'

class Figaro
  def self.env
    Environment
  end

  def self.setup(path)
    Environment.setup(path)
  end

  def self.require_keys(keys)
    Environment.require_keys(keys)
  end

  private
end

class Environment
  def self.setup(path, env = Rails.env)
    @config = {}
    values = YAML.load(ERB.new(File.read(path)).result)

    keys = Set.new(values.keys - ['production', 'development', 'test'])
    keys |= values[env].keys

    keys.each do |key|
      value = values[env][key] || values[key]

      if key == key.upcase
        ENV[key] = value
      end

      @config[key] = value
    end

    @config
  end

  def self.method_missing(m, *args, &block)
    string_key = m.to_s
    key = string_key.tr('?!', '')
    raise_exception = string_key.ends_with?('!')

    if raise_exception
      value = send(key)
      raise "Missing config key #{key}" unless value
      value
    else
      @config[key]
    end
  end

  def self.require_keys(keys)
    keys.each do |key|
      raise "#{key} is missing" unless @config.has_key?(key)
    end

    true
  end
end
