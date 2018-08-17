require 'rails_helper'

describe Idv::OtpDeliveryMethodForm do
  let(:otp_delivery_preference) { 'sms' }
  let(:params) { { otp_delivery_preference: otp_delivery_preference } }

  describe '#submit' do
    context 'with sms as the delivery method' do
      it 'is successful' do
        result = subject.submit(params)

        expect(result.success?).to eq(true)
        expect(subject.otp_delivery_preference).to eq('sms')
      end
    end

    context 'with voice as the delivery method' do
      let(:otp_delivery_preference) { 'voice' }

      it 'is successful' do
        result = subject.submit(params)

        expect(result.success?).to eq(true)
        expect(subject.otp_delivery_preference).to eq('voice')
      end
    end

    context 'with an unsupported value as the delivery method' do
      let(:otp_delivery_preference) { '☎️' }

      it 'is unsuccessful' do
        result = subject.submit(params)

        expect(result.success?).to eq(false)
      end
    end
  end
end
