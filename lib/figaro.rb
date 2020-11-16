require 'yaml'

class Figaro
  class << self
    attr_reader :env
  end

  def self.setup(path, env = Rails.env)
    @env ||= Environment.new(path, env)
  end

  def self.require_keys(keys)
    env.require_keys(keys)
  end

  class Environment
    def initialize(configuration, env)
      @config = {}

      keys = Set.new(configuration.keys - %w[production development test])
      keys |= configuration[env]&.keys || []

      keys.each do |key|
        value = configuration.dig(env, key) || configuration[key]
        env_value = ENV[key]

        if env_value
          warn "WARNING: #{key} is being loaded from ENV instead of application.yml"
          @config[key] = env_value
        else
          @config[key] = value
          ENV[key] = value if key == key.upcase
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
