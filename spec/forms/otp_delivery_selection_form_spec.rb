require 'rails_helper'

describe OtpDeliverySelectionForm do
  let(:phone_to_deliver_to) { '+1 (202) 555-1234' }
  subject do
    OtpDeliverySelectionForm.new(
      build(:user),
      phone_to_deliver_to,
      'authentication',
    )
  end

  describe 'otp_delivery_preference inclusion validation' do
    it 'is invalid when otp_delivery_preference is neither sms nor voice' do
      [nil, '', 'foo'].each do |method|
        subject.submit(otp_delivery_preference: method)
        expect(subject).to_not be_valid
      end
    end
  end

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns true for success?' do
        extra = {
          otp_delivery_preference: 'sms',
          resend: true,
          country_code: 'US',
          area_code: '202',
          context: 'authentication',
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
        }

        expect(subject.submit(otp_delivery_preference: 'sms', resend: 'true').to_h).to eq(
          success: true,
          errors: {},
          **extra,
        )
      end
    end

    context 'when the form is invalid' do
      it 'returns false for success? and includes errors' do
        errors = {
          otp_delivery_preference: ['is not included in the list'],
          phone: ['Please fill in this field.'],
        }

        extra = {
          otp_delivery_preference: 'foo',
          resend: false,
          country_code: nil,
          area_code: nil,
          context: 'authentication',
        }

        subject = OtpDeliverySelectionForm.new(
          build_stubbed(:user),
          nil,
          'authentication',
        )

        expect(subject.submit(otp_delivery_preference: 'foo').to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'with voice preference and unsupported phone' do
      it 'changes the otp_delivery_preference to sms' do
        user = build_stubbed(:user, otp_delivery_preference: 'voice')
        form = OtpDeliverySelectionForm.new(
          user,
          '+12423270143',
          'authentication',
        )
        attributes = { otp_delivery_preference: 'sms' }

        updated_user = instance_double(UpdateUser)
        allow(UpdateUser).to receive(:new).
          with(user: user, attributes: attributes).and_return(updated_user)

        expect(updated_user).to receive(:call)

        form.submit(otp_delivery_preference: 'voice')
      end
    end

    context 'with voice preference and supported phone' do
      it 'does not change the otp_delivery_preference to sms' do
        user = build_stubbed(:user, otp_delivery_preference: 'voice')
        form = OtpDeliverySelectionForm.new(
          user,
          '+17035551212',
          'authentication',
        )

        expect(UpdateUser).to_not receive(:new)

        form.submit(otp_delivery_preference: 'voice')
      end
    end
  end
end
