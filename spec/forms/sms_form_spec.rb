require 'rails_helper'

describe SmsForm do
  describe '#submit' do
    let(:url) { 'https://example.com' }
    let(:signature) { 'signature' }

    before do
      # Only testing our validation here; service spec tests Twilio msg failing
      allow_any_instance_of(Twilio::Security::RequestValidator).to(
        receive(:validate).and_return(true),
      )
    end

    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        good_params = { Body: 'STOP', FromCountry: 'US', MessageSid: '1' }
        message = TwilioService::Sms::Request.new(url, good_params, signature)
        form = SmsForm.new(message)

        result = instance_double(FormResponse)
        extra = { message_sid: '1', from_country: 'US' }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        bad_params = { Body: 'SPORK', FromCountry: 'US', MessageSid: '1' }
        message = TwilioService::Sms::Request.new(url, bad_params, signature)
        form = SmsForm.new(message)
        errors = { base: [t('errors.messages.twilio_inbound_sms_invalid')] }

        result = instance_double(FormResponse)
        extra = { message_sid: '1', from_country: 'US' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit).to eq result
      end
    end
  end
end
