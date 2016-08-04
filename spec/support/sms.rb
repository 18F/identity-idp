SmsSpec.driver = :'twilio-ruby'

RSpec.configure do |config|
  config.include SmsSpec::Helpers, sms: true
  config.include Features::ActiveJobHelper, sms: true

  config.before(:each, sms: true) do
    clear_messages
    reset_job_queues
  end
end
