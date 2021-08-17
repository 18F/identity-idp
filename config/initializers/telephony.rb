# rubocop:disable Metrics/BlockLength
Telephony.config do |c|
  c.adapter = IdentityConfig.store.telephony_adapter.to_sym
  c.logger = if FeatureManagement.log_to_stdout?
               Logger.new(STDOUT, level: :info)
             else
               Logger.new('log/telephony.log', level: :info)
             end

  c.voice_pause_time = IdentityConfig.store.voice_otp_pause_time
  c.voice_rate = IdentityConfig.store.voice_otp_speech_rate

  c.sender_id = IdentityConfig.store.pinpoint_sms_sender_id

  IdentityConfig.store.pinpoint_sms_configs.each do |sms_json_config|
    c.pinpoint.add_sms_config do |sms|
      sms.application_id = sms_json_config['application_id']
      sms.region = sms_json_config['region']
      sms.shortcode = sms_json_config['shortcode']
      sms.credential_role_arn = sms_json_config['credential_role_arn']
      if sms_json_config['credential_role_arn'].present?
        sms.credential_role_session_name = Socket.gethostname
      end
    end
  end

  IdentityConfig.store.pinpoint_voice_configs.each do |voice_json_config|
    c.pinpoint.add_voice_config do |voice|
      voice.region = voice_json_config['region']
      voice.longcode_pool = voice_json_config['longcode_pool'] || []
      voice.credential_role_arn = voice_json_config['credential_role_arn']
      if voice_json_config['credential_role_arn'].present?
        voice.credential_role_session_name = Socket.gethostname
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
