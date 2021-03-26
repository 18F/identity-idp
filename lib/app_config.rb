require 'yaml'

class AppConfig
  class << self
    attr_reader :env
  end

  def self.setup(configuration, env = Rails.env)
    @env ||= Environment.new(configuration, env)
  end

  def self.require_keys(keys)
    env.require_keys(keys)
  end

  class Environment
    attr_reader :config

    def initialize(configuration, env)
      @config = {}

      keys = Set.new(configuration.keys - %w[production development test])
      keys |= configuration[env]&.keys || []

      keys.each do |key|
        value = configuration.dig(env, key) || configuration[key]
        env_value = ENV[key]

        check_string_key(key)
        check_string_value(key, value)

        if env_value
          warn "WARNING: #{key} is being loaded from ENV instead of application.yml"
          @config[key] = env_value
        else
          @config[key] = value
          ENV[key] = value
        end
      end
    end

    def require_keys(keys)
      keys.each do |key|
        raise "#{key} is missing" unless @config.key?(key)
      end

      true
    end

    def respond_to?(method_name)
      key = method_name.to_s
      @config.key?(key)
    end

    private

    def check_string_key(key)
      warn "AppConfig WARNING: key #{key} must be String" unless key.is_a?(String)
    end

    def check_string_value(key, value)
      warn "AppConfig WARNING: #{key} value must be String" unless value.nil? || value.is_a?(String)
    end

    def respond_to_missing?(method_name, _include_private = false)
      key = method_name.to_s
      @config.key?(key)
    end

    def method_missing(method, *_args)
      key = method.to_s

      @config[key]
    end
  end
end
