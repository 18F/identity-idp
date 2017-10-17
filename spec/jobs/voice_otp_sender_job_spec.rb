require 'rails_helper'
include Features::ActiveJobHelper

describe VoiceOtpSenderJob do
  describe '.perform' do
    before do
      TwilioService.telephony_service = FakeVoiceCall
      FakeVoiceCall.calls = []
    end

    let(:cipher) { Gibberish::AES.new(Figaro.env.attribute_encryption_key) }

    it 'initiates the phone call to deliver the OTP', twilio: true do
      I18n.with_locale(:fr) do
        VoiceOtpSenderJob.perform_now(
          code: '1234',
          phone: '555-5555',
          otp_created_at: Time.zone.now.to_s
        )
      end

      calls = FakeVoiceCall.calls

      expect(calls.size).to eq(1)
      call = calls.first
      expect(call.to).to eq('555-5555')
      expect(call.from).to match(/(\+19999999999|\+12222222222)/)

      params = URIService.params(call.url)
      expect(cipher.decrypt(params[:encrypted_code])).to eq('1234')
      expect(params[:locale]).to eq('fr')
    end

    context 'recording calls' do
      let(:twilio_record_voice) { nil }

      before do
        expect(Figaro.env).to receive(:twilio_record_voice).and_return(twilio_record_voice)

        VoiceOtpSenderJob.perform_now(
          code: '1234',
          phone: '555-5555',
          otp_created_at: Time.zone.now.to_s
        )
      end

      context 'when twilio_record_voice is true' do
        let(:twilio_record_voice) { 'true' }

        it 'tells Twilio to record the call' do
          call = FakeVoiceCall.calls.first
          expect(call.record).to eq(true)
        end
      end

      context 'when twilio_record_voice is false' do
        let(:twilio_record_voice) { 'false' }

        it 'tells Twilio to not record the call' do
          call = FakeVoiceCall.calls.first
          expect(call.record).to eq(false)
        end
      end
    end

    it 'does not send if the OTP code is expired' do
      reset_job_queues
      otp_expiration_period = Devise.direct_otp_valid_for

      VoiceOtpSenderJob.perform_now(
        code: '1234',
        phone: '555-5555',
        otp_created_at: otp_expiration_period.ago.to_s
      )

      calls = FakeVoiceCall.calls
      expect(calls.size).to eq(0)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to eq []
    end
  end
end
