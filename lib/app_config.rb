require 'yaml'

module Identity
  module Hostdata
    @env = {}
    @read_env = {}

    String = Struct.new do
      def convert(value)
        value.to_s
      end
    end

    def initialize(read_env)
      @read_env = read_env
    end

    def add(key, type: String, is_required: false, is_sensitive: false)
      value = @read_env[key]
      converted_value = type.convert(value)
      raise 'error' unless Identity::Hostdata.valid?(value, type, is_required)
    end

    def self.valid?(value, type, is_required)
      return false if value.nil? && is_required
      return false if converted_value.nil? && is_required
    end

    def self.build_settings(config_map, &block)
      @read_env = config_map
      block.call(@env)
    end
  end
end

type, optional, sensitive

Identity::Hostdata.build_settings(ENV) do |env|
  env.validate(:some_key_name), type: :int
  env :some_value, default: 'aaa'
  env :some_complex, type: JSONConfig
end

JSONConfig = Struct.new(:value) do
  def parse
    JSON.parse(@value)
  end
end

class AppConfig
  CONFIG_KEY_TYPES = {
    acuant_max_attempts: :integer,
    acuant_attempt_window_in_minutes: :integer,
    aamva_cert_enabled: :boolean,
    aamva_sp_banlist_issuers: :json,
    account_reset_token_valid_for_days: :integer,
    attribute_encryption_key_queue: :json,
    issuers_with_email_nameid_format: [:string],
  }

  class << self
    attr_reader :env
  end

  def self.setup(path, env = Rails.env)
    @env ||= Environment.new(path, env)
  end

  def self.load_configuration(required_keys, env = Rails.env)
    @env ||= Environment.new(path, env)
  end

  def self.require_keys(keys)
    env.require_keys(keys)
  end

  def self.load_keys(config_map, required_keys, env = Rails.env)
    @env_testing = {}
    required_keys.each do |key|
      value = config_map.dig(env, key) || config_map.fetch(key)
      raise if value.nil?

      type = CONFIG_KEY_TYPES[key.to_sym]
      coerced_value = coerce_type(value, type)
      @env_testing[key] = coerced_value
      coerced_value
    end

    @env_testing
  end

  def self.coerce_type(value, type)
    case type
      when :boolean
        return true if value == 'true'
        return false if value == 'false'
        raise 'not a boolean'
      when :integer
        Integer(value)
      when :json
        JSON.parse(value)
      when [:list]
        value.split(',')
      else
        value
    end
  end

  def self.required_sandbox_keys
    %w[
                         acuant_max_attempts
                         acuant_attempt_window_in_minutes
                         async_wait_timeout_seconds
                         attribute_encryption_key
                         database_statement_timeout
                         disallow_all_web_crawlers
                         database_name
                         database_host
                         database_password
                         database_username
                         domain_name
                         enable_rate_limiting
                         enable_test_routes
                         enable_usps_verification
                         exception_recipients
                         hmac_fingerprinter_key
                         idv_attempt_window_in_hours
                         idv_max_attempts
                         idv_send_link_attempt_window_in_minutes
                         idv_send_link_max_attempts
                         issuers_with_email_nameid_format
                         logins_per_ip_limit
                         logins_per_ip_period
                         logins_per_ip_track_only_mode
                         logins_per_email_and_ip_bantime
                         logins_per_email_and_ip_limit
                         logins_per_email_and_ip_period
                         max_mail_events
                         max_mail_events_window_in_days
                         min_password_score
                         mx_timeout
                         newrelic_license_key
                         otp_delivery_blocklist_findtime
                         otp_delivery_blocklist_maxretry
                         otp_valid_for
                         password_max_attempts
                         password_pepper
                         RACK_TIMEOUT_SERVICE_TIMEOUT
                         reauthn_window
                         recovery_code_length
                         recurring_jobs_disabled_names
                         redis_url
                         reg_confirmed_email_max_attempts
                         reg_confirmed_email_window_in_minutes
                         reg_unconfirmed_email_max_attempts
                         reg_unconfirmed_email_window_in_minutes
                         requests_per_ip_limit
                         requests_per_ip_period
                         requests_per_ip_track_only_mode
                         remember_device_expiration_hours_aal_1
                         remember_device_expiration_hours_aal_2
                         reset_password_email_max_attempts
                         reset_password_email_window_in_minutes
                         saml_endpoint_configs
                         scrypt_cost
                         secret_key_base
                         session_encryption_key
                         session_timeout_in_minutes
                         use_kms
                         valid_authn_contexts
    ]
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
