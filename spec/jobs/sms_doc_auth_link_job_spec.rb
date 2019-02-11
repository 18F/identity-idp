require 'rails_helper'

describe SmsDocAuthLinkJob do
  include Features::ActiveJobHelper
  include Rails.application.routes.url_helpers

  describe '.perform' do
    before do
      reset_job_queues
      TwilioService::Utils.telephony_service = FakeSms
      FakeSms.messages = []
    end

    subject(:perform) do
      SmsDocAuthLinkJob.perform_now(
        phone: '+1 (888) 555-5555',
        link: root_url,
        app: 'login.gov',
      )
    end

    it 'sends a message to the mobile number', twilio: true do
      allow(Figaro.env).to receive(:twilio_messaging_service_sid).and_return('fake_sid')

      TwilioService::Utils.telephony_service = FakeSms

      perform

      messages = FakeSms.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.messaging_service_sid).to eq('fake_sid')
      expect(msg.to).to eq('+1 (888) 555-5555')
      expect(msg.body).
        to eq(I18n.t('jobs.sms_doc_auth_link_job.message',
                     application: 'login.gov',
                     sp_link: root_url))
    end
  end
end
