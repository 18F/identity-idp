require 'rails_helper'

describe Idv::OtpDeliveryMethodPresenter do
  let(:phone) { '555-555-0000' }
  let(:formatted_phone) { '+1 (555) 555-0000' }
  let(:phone_number_capabilities) { PhoneNumberCapabilities.new(formatted_phone) }

  subject { Idv::OtpDeliveryMethodPresenter.new(phone) }

  before do
    allow(PhoneNumberCapabilities).to receive(:new).
      with(formatted_phone).
      and_return(phone_number_capabilities)
  end

  describe '#phone_unsupported_message' do
    it 'returns a message saying the phone is unsupported in the location' do
      unsupported_location = '🌃🌇🏙🌇🌃'
      allow(phone_number_capabilities).to receive(:sms_only?).and_return(true)
      allow(phone_number_capabilities).to receive(:unsupported_location).
        and_return(unsupported_location)

      expect(subject.phone_unsupported_message).to eq(
        t(
          'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: unsupported_location
        )
      )
    end
  end
end
