Telephony.config do |c|
  c.adapter = Figaro.env.telephony_adapter.to_sym || :test
  c.twilio_numbers = JSON.parse(Figaro.env.twilio_numbers)
  c.twilio_sid = Figaro.env.twilio_sid
  c.twilio_auth_token = Figaro.env.twilio_auth_token
  c.twilio_messaging_service_sid = Figaro.env.twilio_messaging_service_sid
  c.twilio_verify_api_key = Figaro.env.twilio_verify_api_key
  c.twilio_voice_callback_encryption_key = Figaro.env.twilio_voice_callback_encryption_key
  c.twilio_voice_callback_base_url = "https://#{Figaro.env.domain_name}/api/twilio/voice"
  c.twilio_timeout = Figaro.env.twilio_timeout.to_i unless Figaro.env.twilio_timeout.nil?
  c.twilio_record_voice = Figaro.env.twilio_record_voice == 'true'
  c.pinpoint_region = Figaro.env.aws_region
  c.pinpoint_application_id = Figaro.env.pinpoint_application_id
  c.pinpoint_shortcode = Figaro.env.pinpoint_shortcode
  c.pinpoint_longcode_pool = JSON.parse(Figaro.env.pinpoint_longcode_pool || '[]')
end
