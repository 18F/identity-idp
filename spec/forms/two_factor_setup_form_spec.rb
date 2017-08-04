require 'rails_helper'

describe TwoFactorSetupForm, type: :model do
  let(:user) { build_stubbed(:user) }
  let(:phone) { '+1 (202) 202-2020' }
  let(:international_code) { 'US' }
  let(:params) do
    {
      phone: phone,
      international_code: 'US',
      otp_delivery_preference: 'sms',
    }
  end
  subject { TwoFactorSetupForm.new(user) }

  it_behaves_like 'an otp delivery preference form'

  it do
    is_expected.
      to validate_presence_of(:phone).
      with_message(t('errors.messages.improbable_phone'))
  end

  describe 'phone validation' do
    it 'uses the phony_rails gem' do
      phone_validator = subject._validators.values.flatten.
                        detect { |v| v.class == PhonyPlausibleValidator }

      expect(phone_validator.options[:presence]).to eq(true)
      expect(phone_validator.options[:message]).to eq(:improbable_phone)
      expect(phone_validator.options).to include(:international_code)
    end

    it do
      should validate_inclusion_of(:international_code).
        in_array(PhoneNumberCapabilities::INTERNATIONAL_CODES.keys)
    end

    it 'validates that the number matches the requested international code' do
      params[:phone] = '123 123 1234'
      params[:international_code] = 'MA'
      result = subject.submit(params)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to include(:phone)
    end
  end

  describe 'phone uniqueness' do
    context 'when phone is already taken' do
      it 'is valid' do
        user = build_stubbed(:user, :signed_up, phone: '+1 (202) 555-1213')
        allow(User).to receive(:exists?).with(phone: user.phone).and_return(true)
        form = TwoFactorSetupForm.new(user)
        extra = {
          otp_delivery_preference: 'sms',
        }
        result = instance_double(FormResponse)

        params[:phone] = user.phone

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit(params)).to eq result
      end
    end

    context 'when phone is not already taken' do
      let(:phone) { '+1 (703) 555-1212' }

      it 'is valid' do
        extra = {
          otp_delivery_preference: 'sms',
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit(params)).to eq result
      end
    end

    context 'when phone is same as current user' do
      it 'is valid' do
        user = build_stubbed(:user, phone: phone)
        form = TwoFactorSetupForm.new(user)
        extra = {
          otp_delivery_preference: 'sms',
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit(params)).to eq result
      end
    end

    context 'when phone is empty' do
      let(:phone) { '' }

      it 'does not add already taken errors' do
        errors = {
          phone: [t('errors.messages.improbable_phone')],
        }
        extra = {
          otp_delivery_preference: 'sms',
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(subject.submit(params)).to eq result
      end
    end
  end

  describe '#submit' do
    context 'when otp_delivery_preference is the same as the user otp_delivery_preference' do
      it 'does not update the user' do
        user = build_stubbed(:user, otp_delivery_preference: 'sms')
        form = TwoFactorSetupForm.new(user)

        expect(UpdateUser).to_not receive(:new)

        form.submit(params)
      end
    end

    context 'when otp_delivery_preference is different from the user otp_delivery_preference' do
      it 'updates the user' do
        user = build_stubbed(:user, otp_delivery_preference: 'voice')
        form = TwoFactorSetupForm.new(user)
        attributes = { otp_delivery_preference: 'sms' }

        updated_user = instance_double(UpdateUser)
        allow(UpdateUser).to receive(:new).
          with(user: user, attributes: attributes).and_return(updated_user)

        expect(updated_user).to receive(:call)

        form.submit(params)
      end
    end
  end
end
