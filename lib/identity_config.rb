class IdentityConfig
  class << self
    attr_reader :store
  end

  CONVERTERS = {
    uri: proc { |value| URI(value) },
    string: proc { |value| value.to_s },
    comma_separated_string_list: proc do |value|
      value.split(',')
    end,
    integer: proc do |value|
      Integer(value)
    end,
    json: proc do |value, options: {}|
      JSON.parse(value, symbolize_names: options[:symbolize_names])
    end,
    boolean: proc do |value|
      case value
      when 'true', true
        true
      when 'false', false
        false
      else
        raise 'invalid boolean value'
      end
    end,
  }

  def initialize(read_env)
    @read_env = read_env
    @written_env = {}
  end

  def add(key, type: :string, is_sensitive: false, options: {})
    value = @read_env[key]
    raise "#{key} is required but is not present" if value.nil?
    converted_value = CONVERTERS.fetch(type).call(value, options: options)
    raise "#{key} is required but is not present" if converted_value.nil?

    @written_env[key] = converted_value
    @written_env
  end

  def self.build_store(config_map)
    config = IdentityConfig.new(config_map)
    config.add(:aamva_sp_banlist_issuers, type: :json)
    config.add(:attribute_encryption_key_queue, type: :json)
    config.add(:aws_kms_regions, type: :json)
    config.add(:deleted_user_accounts_report_configs, type: :json)
    config.add(:exception_recipients, type: :comma_separated_string_list)
    config.add(:hmac_fingerprinter_key_queue, type: :json)
    config.add(:issuers_with_email_nameid_format, type: :comma_separated_string_list)
    config.add(:no_sp_campaigns_whitelist, type: :json)
    config.add(:nonessential_email_banlist, type: :json)
    config.add(:recurring_jobs_disabled_names, type: :json)
    config.add(:saml_endpoint_configs, type: :json, options: { symbolize_names: true })
    config.add(:skip_encryption_allowed_list, type: :json)
    config.add(:sps_over_quota_limit_notify_email_list, type: :json)
    final_env = config.add(:valid_authn_contexts, type: :json)

    @store = RedactedStruct.new('IdentityConfig', *final_env.keys, keyword_init: true).
      new(**final_env)
  end
end
