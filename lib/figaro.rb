require 'yaml'
require 'erb'

class Figaro
  def self.env
    @env ||= Environment.new
  end

  def self.setup(path)
    env.setup(path)
  end

  def self.require_keys(keys)
    env.require_keys(keys)
  end

  class Environment
    def setup(path, env = Rails.env)
      @config = {}
      values = YAML.safe_load(File.read(path))

      keys = Set.new(values.keys - %w[production development test])
      keys |= values[env].keys

      keys.each do |key|
        value = values[env][key] || values[key]

        ENV[key] = value if key == key.upcase

        @config[key] = value
      end

      @config
    end

    def respond_to_missing?(method_name, _include_private = false)
      key = method_name.to_s.tr('?!', '')
      @config.key?(key)
    end

    def method_missing(method, *_args)
      string_key = method.to_s
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

    def require_keys(keys)
      keys.each do |key|
        raise "#{key} is missing" unless @config.key?(key)
      end

      true
    end
  end
end
