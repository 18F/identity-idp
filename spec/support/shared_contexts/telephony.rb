require 'telephony'

def telephony_use_default_config!
  # Setup some default configs
  Telephony.config do |c|
    c.logger = Logger.new(nil)

    c.voice_pause_time = '0.5s'
    c.voice_rate = 'slow'

    c.pinpoint.add_sms_config do |sms|
      sms.region = 'fake-pinpoint-region-sms'
      sms.access_key_id = 'fake-pnpoint-access-key-id-sms'
      sms.secret_access_key = 'fake-pinpoint-secret-access-key-sms'
      sms.application_id = 'fake-pinpoint-application-id-sms'
      sms.shortcode = '123456'
      sms.country_code_longcode_pool = { 'PR' => ['+19393334444'] }
    end

    c.pinpoint.add_voice_config do |voice|
      voice.region = 'fake-pinpoint-region-voice'
      voice.access_key_id = 'fake-pinpoint-access-key-id-voice'
      voice.secret_access_key = 'fake-pinpoint-secret-access-key-voice'
      voice.longcode_pool = ['+12223334444', '+15556667777']
    end
  end
end

RSpec.shared_context 'telephony' do
  before do
    Pinpoint::MockClient.reset!
  end

  around do |ex|
    old_config = Telephony.config.dup
    Telephony.instance_variable_set(:@config, nil)
    telephony_use_default_config!

    ex.run
  ensure
    Telephony.instance_variable_set(:@config, old_config)
  end
end
