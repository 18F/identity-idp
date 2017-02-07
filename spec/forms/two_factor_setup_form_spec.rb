require 'rails_helper'

describe TwoFactorSetupForm, type: :model do
  let(:user) { build_stubbed(:user) }
  let(:valid_phone) { '+1 (202) 202-2020' }
  subject { TwoFactorSetupForm.new(user) }

  it do
    is_expected.
      to validate_presence_of(:phone).
      with_message(t('errors.messages.improbable_phone'))
  end

  describe 'phone validation' do
    it 'uses the phony_rails gem with country option set to US' do
      phone_validator = subject._validators.values.flatten.
                        detect { |v| v.class == PhonyPlausibleValidator }

      expect(phone_validator.options).
        to eq(country_code: 'US', presence: true, message: :improbable_phone)
    end
  end

  describe 'phone uniqueness' do
    context 'when phone is already taken' do
      it 'is valid' do
        user = build_stubbed(:user, :signed_up, phone: '+1 (202) 555-1213')
        allow(User).to receive(:exists?).with(phone: user.phone).and_return(true)
        form = TwoFactorSetupForm.new(user)

        result = {
          success: true,
          error: nil,
          otp_method: 'sms',
        }

        expect(form.submit(phone: user.phone, otp_method: 'sms')).
          to eq result
      end
    end

    context 'when phone is not already taken' do
      it 'is valid' do
        result = {
          success: true,
          error: nil,
          otp_method: 'sms',
        }

        expect(subject.submit(phone: '+1 (703) 555-1212', otp_method: 'sms')).
          to eq result
      end
    end

    context 'when phone is same as current user' do
      it 'is valid' do
        user = build_stubbed(:user, phone: valid_phone)
        form = TwoFactorSetupForm.new(user)

        result = {
          success: true,
          error: nil,
          otp_method: 'sms',
        }

        expect(form.submit(phone: valid_phone, otp_method: 'sms')).
          to eq result
      end
    end

    context 'when phone is empty' do
      it 'does not add already taken errors' do
        result = {
          success: false,
          error: t('errors.messages.improbable_phone'),
          otp_method: 'sms',
        }

        expect(subject.submit(phone: '', otp_method: 'sms')).
          to eq result
      end
    end
  end

  describe '#submit' do
    context 'when otp_method is the same as the user otp_delivery_preference' do
      it 'does not update the user' do
        user = build_stubbed(:user, otp_delivery_preference: 'sms')
        form = TwoFactorSetupForm.new(user)

        expect(UpdateUser).to_not receive(:new)

        form.submit(phone: '+1 (703) 555-1212', otp_method: 'sms')
      end
    end

    context 'when otp_method is different from the user otp_delivery_preference' do
      it 'updates the user' do
        user = build_stubbed(:user, otp_delivery_preference: 'voice')
        form = TwoFactorSetupForm.new(user)
        attributes = { otp_delivery_preference: 'sms' }

        updated_user = instance_double(UpdateUser)
        allow(UpdateUser).to receive(:new).
          with(user: user, attributes: attributes).and_return(updated_user)

        expect(updated_user).to receive(:call)

        form.submit(phone: '+1 (703) 555-1212', otp_method: 'sms')
      end
    end
  end
end
