require 'rails_helper'

describe SmsOtpSenderJob do
  include Features::ActiveJobHelper

  describe '.perform' do
    before do
      reset_job_queues
      TwilioService::Utils.telephony_service = FakeSms
      FakeSms.messages = []
    end

    subject(:perform) do
      SmsOtpSenderJob.perform_now(
        code: '1234',
        phone: '+1 (888) 555-5555',
        message: 'jobs.sms_otp_sender_job.login_message',
        otp_created_at: otp_created_at
      )
    end

    let(:otp_created_at) { Time.zone.now.to_s }

    it 'sends a sign in message containing the OTP code to the mobile number', twilio: true do
      allow(Figaro.env).to receive(:twilio_messaging_service_sid).and_return('fake_sid')

      TwilioService::Utils.telephony_service = FakeSms

      perform

      messages = FakeSms.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.messaging_service_sid).to eq('fake_sid')
      expect(msg.to).to eq('+1 (888) 555-5555')
      expect(msg.body).to eq(
        I18n.t('jobs.sms_otp_sender_job.login_message',
               code: '1234', app: APP_NAME, expiration: '10')
      )
    end

    it 'sends a verify message containing the OTP code to the mobile number', twilio: true do
      allow(Figaro.env).to receive(:twilio_messaging_service_sid).and_return('fake_sid')

      TwilioService::Utils.telephony_service = FakeSms

      SmsOtpSenderJob.perform_now(
        code: '1234',
        phone: '+1 (888) 555-5555',
        message: 'jobs.sms_otp_sender_job.verify_message',
        otp_created_at: otp_created_at
      )

      messages = FakeSms.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.messaging_service_sid).to eq('fake_sid')
      expect(msg.to).to eq('+1 (888) 555-5555')
      expect(msg.body).to eq(I18n.t('jobs.sms_otp_sender_job.verify_message',
                                    code: '1234', app: APP_NAME, expiration: '10'))
    end
    it 'includes the expiration period in the message body' do
      allow(I18n).to receive(:locale).and_return(:en).at_least(:once)
      allow(Devise).to receive(:direct_otp_valid_for).and_return(4.minutes)

      TwilioService::Utils.telephony_service = FakeSms

      perform

      message = FakeSms.messages.first

      expect(message.body).to include('4 minutes')
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

    context 'when the phone number country is not in the programmable_sms_countries list' do
      it 'sends the SMS via PhoneVerification class' do
        PhoneVerification.adapter = FakeAdapter
        phone = '+1 787-327-0143'
        code = '123456'
        verification = instance_double(PhoneVerification)
        locale = 'fr'

        expect(PhoneVerification).to receive(:new).
          with(phone: phone, locale: locale, code: code).
          and_return(verification)
        expect(verification).to receive(:send_sms)

        SmsOtpSenderJob.perform_now(
          code: code,
          phone: phone,
          otp_created_at: otp_created_at,
          message: nil,
          locale: locale
        )
      end
    end

    context 'when the phone number country is in the programmable_sms_countries list' do
      it 'sends the SMS via TwilioService' do
        allow(Figaro.env).to receive(:programmable_sms_countries).and_return('US,CA,FR')
        phone = '+33 661 32 70 14'
        service = instance_double(TwilioService::Utils)
        code = '123456'

        expect(TwilioService::Utils).to receive(:new).and_return(service)
        expect(service).to receive(:send_sms).with(
          to: phone,
          body: I18n.t(
            'jobs.sms_otp_sender_job.login_message',
            code: code, app: APP_NAME, expiration: Devise.direct_otp_valid_for.to_i / 60
          )
        )

        SmsOtpSenderJob.perform_now(
          code: code,
          phone: phone,
          otp_created_at: otp_created_at,
          message: 'jobs.sms_otp_sender_job.login_message',
          locale: 'fr'
        )
      end
    end
  end
end
