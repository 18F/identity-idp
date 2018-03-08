require 'rails_helper'

describe SmsResetDeviceNotifierJob do
  include Features::ActiveJobHelper
  include Rails.application.routes.url_helpers

  describe '.perform' do
    before do
      reset_job_queues
      TwilioService.telephony_service = FakeSms
      FakeSms.messages = []
    end

    subject(:perform) do
      SmsResetDeviceNotifierJob.perform_now(
        phone: '+1 (888) 555-5555',
        cancel_token: 'UUID1'
      )
    end

    it 'sends a message containing the cancel link to the mobile number', twilio: true do
      allow(Figaro.env).to receive(:twilio_messaging_service_sid).and_return('fake_sid')

      TwilioService.telephony_service = FakeSms

      perform

      messages = FakeSms.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.messaging_service_sid).to eq('fake_sid')
      expect(msg.to).to eq('+1 (888) 555-5555')
      expect(msg.body).to eq(I18n.t('jobs.sms_reset_device_notifier_job.message', app: APP_NAME,
        cancel_link: reset_device_cancel_url(token: 'UUID1')))
    end
  end
end
