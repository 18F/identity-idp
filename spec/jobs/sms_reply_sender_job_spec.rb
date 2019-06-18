require 'rails_helper'

describe SmsReplySenderJob do
  include Features::ActiveJobHelper

  describe '.perform' do
    before do
      reset_job_queues
    end

    let(:sid) { 'fake_sid' }
    let(:phone) { '202-555-5555' }
    let(:body) { 'Helpful information' }

    subject(:perform) do
      SmsReplySenderJob.perform_now(
        to: phone,
        body: body,
      )
    end

    it 'sends a reply to the mobile number' do
      allow(Figaro.env).to receive(:twilio_messaging_service_sid).and_return(sid)

      perform

      messages = Twilio::FakeMessage.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.messaging_service_sid).to eq(sid)
      expect(msg.to).to eq(phone)
      expect(msg.body).to eq(body)
    end
  end
end
