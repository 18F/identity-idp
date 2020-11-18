# rubocop:disable Metrics/BlockLength
Telephony.config do |c|
  c.adapter = AppConfig.env.telephony_adapter.to_sym || :test
  c.logger = if FeatureManagement.log_to_stdout?
               Logger.new(STDOUT, level: :info)
             else
               Logger.new('log/telephony.log', level: :info)
             end

  c.twilio.numbers = JSON.parse(AppConfig.env.twilio_numbers || '[]')
  c.twilio.sid = AppConfig.env.twilio_sid
  c.twilio.auth_token = AppConfig.env.twilio_auth_token
  c.twilio.messaging_service_sid = AppConfig.env.twilio_messaging_service_sid
  c.twilio.voice_callback_encryption_key = AppConfig.env.twilio_voice_callback_encryption_key
  c.twilio.voice_callback_base_url = "https://#{AppConfig.env.domain_name}/api/twilio/voice"
  c.twilio.timeout = AppConfig.env.twilio_timeout.to_i unless AppConfig.env.twilio_timeout.nil?
  c.twilio.record_voice = AppConfig.env.twilio_record_voice == 'true'

  if AppConfig.env.pinpoint_sms_configs.present?
    JSON.parse(AppConfig.env.pinpoint_sms_configs || '[]').each do |sms_json_config|
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
  else
    c.pinpoint.add_sms_config do |sms|
      sms.region = AppConfig.env.pinpoint_sms_region
      sms.application_id = AppConfig.env.pinpoint_sms_application_id
      sms.shortcode = AppConfig.env.pinpoint_sms_shortcode
      sms.credential_role_arn = AppConfig.env.pinpoint_sms_credential_role_arn
      if AppConfig.env.pinpoint_sms_credential_role_arn.present?
        sms.credential_role_session_name = Socket.gethostname
      end
    end
  end

  if AppConfig.env.pinpoint_voice_configs.present?
    JSON.parse(AppConfig.env.pinpoint_voice_configs || '[]').each do |voice_json_config|
      c.pinpoint.add_voice_config do |voice|
        voice.region = voice_json_config['region']
        voice.longcode_pool = voice_json_config['longcode_pool'] || []
        voice.credential_role_arn = voice_json_config['credential_role_arn']
        if voice_json_config['credential_role_arn'].present?
          voice.credential_role_session_name = Socket.gethostname
        end
      end
    end
  else
    c.pinpoint.add_voice_config do |voice|
      voice.region = AppConfig.env.pinpoint_voice_region
      voice.longcode_pool = JSON.parse(AppConfig.env.pinpoint_voice_longcode_pool || '[]')
      voice.credential_role_arn = AppConfig.env.pinpoint_voice_credential_role_arn
      if AppConfig.env.pinpoint_voice_credential_role_arn.present?
        voice.credential_role_session_name = Socket.gethostname
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
