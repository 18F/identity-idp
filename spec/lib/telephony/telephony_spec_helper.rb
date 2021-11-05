require 'i18n/tasks'
require 'pry-byebug'
require 'webmock/rspec'
require 'telephony/telephony'

Dir[File.dirname(__FILE__) + '/support/*.rb'].sort.each { |file| require file }

def use_default_config!
  # Setup some default configs
  Telephony.instance_variable_set(:@config, nil)

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
    end

    c.pinpoint.add_voice_config do |voice|
      voice.region = 'fake-pinpoint-region-voice'
      voice.access_key_id = 'fake-pinpoint-access-key-id-voice'
      voice.secret_access_key = 'fake-pinpoint-secret-access-key-voice'
      voice.longcode_pool = ['+12223334444', '+15556667777']
    end
  end
end

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.before(:each) do
    Pinpoint::MockClient.reset!

    use_default_config!
  end
end

WebMock.disable_net_connect!

I18n.available_locales = [:en, :es, :fr]

# Raise missing translation errors in the specs so that missing translations
# will trigger a test failure
I18n.exception_handler = lambda do |exception, _locale, _key, _options|
  raise exception
end
