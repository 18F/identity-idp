require 'rails_helper'

describe SmsPersonalKeyRegenerationNotifierJob do
  include Features::ActiveJobHelper

  before do
    reset_job_queues
    TwilioService::Utils.telephony_service = FakeSms
    FakeSms.messages = []
  end

  describe '.perform' do
    it 'sends a message about the personal key sign in to the user' do
      allow(Figaro.env).to receive(:twilio_messaging_service_sid).and_return('fake_sid')

      described_class.perform_now(phone: '+1 (202) 345-6789')

      messages = FakeSms.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.messaging_service_sid).to eq('fake_sid')
      expect(msg.to).to eq('+1 (202) 345-6789')
      expect(msg.body).
        to eq(I18n.t('jobs.sms_personal_key_regeneration_notifier_job.message', app: APP_NAME))
    end
  end
end
