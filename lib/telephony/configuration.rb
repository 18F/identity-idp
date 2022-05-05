require 'logger'

module Telephony
  class PinpointConfiguration
    attr_reader :sms_configs, :voice_configs

    def initialize
      @sms_configs = []
      @voice_configs = []
    end

    # Adds a new SMS configuration
    # @yieldparam [PinpointSmsConfiguration] sms an sms configuration object configure
    def add_sms_config
      raise 'missing sms configuration block' unless block_given?
      sms = PinpointSmsConfiguration.new(region: 'us-west-2')
      yield sms
      sms_configs << sms
      sms
    end

    # Adds a new voice configuration
    # @yieldparam [PinpointVoiceConfiguration] voice a voice configuration object configure
    def add_voice_config
      raise 'missing voice configuration block' unless block_given?
      voice = PinpointVoiceConfiguration.new(region: 'us-west-2')
      yield voice
      voice_configs << voice
      voice
    end
  end

  PINPOINT_CONFIGURATION_NAMES = [
    :region, :access_key_id, :secret_access_key,
    :credential_role_arn, :credential_role_session_name, :credential_external_id
  ].freeze
  PinpointVoiceConfiguration = Struct.new(
    :longcode_pool,
    *PINPOINT_CONFIGURATION_NAMES,
    keyword_init: true,
  )
  PinpointSmsConfiguration = Struct.new(
    :application_id,
    :shortcode,
    :country_code_longcode_pool,
    *PINPOINT_CONFIGURATION_NAMES,
    keyword_init: true,
  )

  class Configuration
    attr_writer :adapter
    attr_reader :pinpoint
    attr_accessor :logger
    attr_accessor :voice_pause_time
    attr_accessor :voice_rate

    def initialize
      @adapter = :pinpoint
      @logger = Logger.new(STDOUT)
      @pinpoint = PinpointConfiguration.new
    end

    def adapter
      @adapter.to_sym
    end

    # @param [Hash,nil] map
    def country_sender_ids=(hash)
      @country_sender_ids = hash&.transform_keys(&:to_s)
    end

    def country_sender_ids
      @country_sender_ids || {}
    end
  end
end
