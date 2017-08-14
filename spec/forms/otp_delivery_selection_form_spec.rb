require 'rails_helper'

describe OtpDeliverySelectionForm do
  let(:phone_to_deliver_to) { '+1 (202) 555-1234' }
  subject do
    OtpDeliverySelectionForm.new(
      build_stubbed(:user),
      phone_to_deliver_to,
      'authentication'
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
          country_code: '1',
          area_code: '202',
          context: 'authentication',
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit(otp_delivery_preference: 'sms', resend: true)).to eq result
      end
    end

    context 'when the form is invalid' do
      it 'returns false for success? and includes errors' do
        errors = { otp_delivery_preference: ['is not included in the list'] }

        extra = {
          otp_delivery_preference: 'foo',
          resend: nil,
          country_code: '1',
          area_code: '202',
          context: 'authentication',
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(subject.submit(otp_delivery_preference: 'foo')).to eq result
      end
    end

    context 'with authentication context' do
      context 'when otp_delivery_preference is the same as the user otp_delivery_preference' do
        it 'does not update the user' do
          user = build_stubbed(:user, otp_delivery_preference: 'sms')
          form = OtpDeliverySelectionForm.new(user, phone_to_deliver_to, 'authentication')

          expect(UpdateUser).to_not receive(:new)

          form.submit(otp_delivery_preference: 'sms')
        end
      end

      context 'when otp_delivery_preference is different from the user otp_delivery_preference' do
        it 'updates the user' do
          user = build_stubbed(:user, otp_delivery_preference: 'voice')
          form = OtpDeliverySelectionForm.new(user, phone_to_deliver_to, 'authentication')
          attributes = { otp_delivery_preference: 'sms' }

          updated_user = instance_double(UpdateUser)
          allow(UpdateUser).to receive(:new).
            with(user: user, attributes: attributes).and_return(updated_user)

          expect(updated_user).to receive(:call)

          form.submit(otp_delivery_preference: 'sms')
        end
      end
    end

    context 'with idv context' do
      context 'when otp_delivery_preference is the same as the user otp_delivery_preference' do
        it 'does not update the user' do
          user = build_stubbed(:user, otp_delivery_preference: 'sms')
          form = OtpDeliverySelectionForm.new(user, phone_to_deliver_to, 'idv')

          expect(UpdateUser).to_not receive(:new)

          form.submit(otp_delivery_preference: 'sms')
        end
      end

      context 'when otp_delivery_preference is different from the user otp_delivery_preference' do
        it 'does not update the user' do
          user = build_stubbed(:user, otp_delivery_preference: 'voice')
          form = OtpDeliverySelectionForm.new(user, phone_to_deliver_to, 'idv')

          expect(UpdateUser).to_not receive(:new)

          form.submit(otp_delivery_preference: 'sms')
        end
      end
    end
  end
end
