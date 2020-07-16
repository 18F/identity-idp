# rubocop:disable Metrics/BlockLength
Telephony.config do |c|
  c.adapter = Figaro.env.telephony_adapter.to_sym || :test
  if Figaro.env.log_to_stdout?
    c.logger = Logger.new(STDOUT, level: :info)
  else
    c.logger = Logger.new('log/telephony.log', level: :info)
  end

  c.twilio.numbers = JSON.parse(Figaro.env.twilio_numbers || '[]')
  c.twilio.sid = Figaro.env.twilio_sid
  c.twilio.auth_token = Figaro.env.twilio_auth_token
  c.twilio.messaging_service_sid = Figaro.env.twilio_messaging_service_sid
  c.twilio.voice_callback_encryption_key = Figaro.env.twilio_voice_callback_encryption_key
  c.twilio.voice_callback_base_url = "https://#{Figaro.env.domain_name}/api/twilio/voice"
  c.twilio.timeout = Figaro.env.twilio_timeout.to_i unless Figaro.env.twilio_timeout.nil?
  c.twilio.record_voice = Figaro.env.twilio_record_voice == 'true'

  if Figaro.env.pinpoint_sms_configs.present?
    JSON.parse(Figaro.env.pinpoint_sms_configs || '[]').each do |sms_json_config|
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
      sms.region = Figaro.env.pinpoint_sms_region
      sms.application_id = Figaro.env.pinpoint_sms_application_id
      sms.shortcode = Figaro.env.pinpoint_sms_shortcode
      sms.credential_role_arn = Figaro.env.pinpoint_sms_credential_role_arn
      if Figaro.env.pinpoint_sms_credential_role_arn.present?
        sms.credential_role_session_name = Socket.gethostname
      end
    end
  end

  if Figaro.env.pinpoint_voice_configs.present?
    JSON.parse(Figaro.env.pinpoint_voice_configs || '[]').each do |voice_json_config|
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
      voice.region = Figaro.env.pinpoint_voice_region
      voice.longcode_pool = JSON.parse(Figaro.env.pinpoint_voice_longcode_pool || '[]')
      voice.credential_role_arn = Figaro.env.pinpoint_voice_credential_role_arn
      if Figaro.env.pinpoint_voice_credential_role_arn.present?
        voice.credential_role_session_name = Socket.gethostname
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
