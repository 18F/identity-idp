require 'rails_helper'
include Features::ActiveJobHelper

describe SmsOtpSenderJob do
  describe '.perform' do
    before do
      reset_job_queues
      TwilioService.telephony_service = FakeSms
      FakeSms.messages = []
    end

    subject(:perform) do
      SmsOtpSenderJob.perform_now(
        code: '1234',
        phone: '+1 (888) 555-5555',
        otp_created_at: otp_created_at
      )
    end

    let(:otp_created_at) { Time.zone.now.to_s }

    it 'sends a message containing the OTP code to the mobile number', twilio: true do
      TwilioService.telephony_service = FakeSms

      perform

      messages = FakeSms.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.from).to match(/(\+19999999999|\+12222222222)/)
      expect(msg.to).to eq('+1 (888) 555-5555')
      expect(msg.body).to eq(I18n.t('jobs.sms_otp_sender_job.message', code: '1234', app: APP_NAME))
    end

    context 'if the OTP code is expired' do
      let(:otp_created_at) do
        otp_expiration_period = Devise.direct_otp_valid_for
        otp_expiration_period.ago.to_s
      end

      it 'does not send if the OTP code is expired' do
        perform

        messages = FakeSms.messages
        expect(messages.size).to eq(0)
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to eq []
      end
    end

    context 'in other time zones' do
      let(:otp_created_at) do
        otp_expiration_period = Devise.direct_otp_valid_for
        otp_expiration_period.ago.strftime('%F %r')
      end

      it 'respects time zone' do
        perform

        messages = FakeSms.messages
        expect(messages.size).to eq(0)
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to eq []
      end
    end
  end
end
