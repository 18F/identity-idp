require 'rails_helper'

describe SmsNewDeviceSignInNotifierJob do
  include Features::ActiveJobHelper

  before do
    reset_job_queues
    TwilioService::Utils.telephony_service = FakeSms
    FakeSms.messages = []
  end

  describe '.perform' do
    it 'sends a message about signing in from a new device to the user' do
      allow(Figaro.env).to receive(:twilio_messaging_service_sid).and_return('fake_sid')

      described_class.perform_now(phone: '+1 (703) 314-3141')

      messages = FakeSms.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.messaging_service_sid).to eq('fake_sid')
      expect(msg.to).to eq('+1 (703) 314-3141')
      expect(msg.body).
          to eq(I18n.t('jobs.sms_new_device_sign_in_notifier_job.message', app: APP_NAME))
    end
  end
end