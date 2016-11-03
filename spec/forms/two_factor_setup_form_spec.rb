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

  describe 'OTP delivery preference' do
    context 'when voice is selected' do
      before do
        subject.submit(phone: valid_phone,
                       otp_method: 'voice')
      end

      it 'sets otp_method to "voice"' do
        expect(subject.otp_method).to eq(:voice)
      end
    end

    context 'when SMS is selected' do
      before do
        subject.submit(phone: valid_phone,
                       otp_method: 'sms')
      end

      it 'sets otp_method to "sms"' do
        expect(subject.otp_method).to eq(:sms)
      end
    end
  end

  describe 'phone uniqueness' do
    context 'when phone is already taken' do
      it 'is valid' do
        user = build_stubbed(:user, :signed_up, phone: '+1 (202) 555-1213')
        allow(User).to receive(:exists?).with(phone: user.phone).and_return(true)

        subject.phone = user.phone

        expect(subject.valid?).to be true
      end
    end

    context 'when phone is not already taken' do
      it 'is valid' do
        subject.phone = '+1 (703) 555-1212'

        expect(subject.valid?).to be true
      end
    end

    context 'when phone is same as current user' do
      before do
        user.phone = valid_phone
      end

      it 'is valid' do
        subject.phone = user.phone

        expect(subject.valid?).to be true
      end
    end

    context 'when phone is nil' do
      it 'does not add already taken errors' do
        subject.phone = nil
        subject.valid?

        expect(subject.errors[:phone].uniq).
          to eq [t('errors.messages.improbable_phone')]
        expect(subject.valid?).to be false
      end
    end
  end
end
