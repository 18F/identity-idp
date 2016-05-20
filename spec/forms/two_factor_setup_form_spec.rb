require 'rails_helper'

describe TwoFactorSetupForm do
  let(:user) { build_stubbed(:user, :signed_up) }
  subject { TwoFactorSetupForm.new(user) }

  it do
    is_expected.
      to validate_presence_of(:mobile).
      with_message(t('errors.messages.improbable_phone'))
  end

  describe 'mobile validation' do
    it 'uses the phony_rails gem with country option set to US' do
      mobile_validator = subject._validators.values.flatten.
                         detect { |v| v.class == PhonyPlausibleValidator }

      expect(mobile_validator.options).
        to eq(country_code: 'US', presence: true, message: :improbable_phone)
    end
  end

  describe 'mobile uniqueness' do
    context 'when mobile is already taken' do
      it 'is invalid' do
        user = build_stubbed(:user, :signed_up, mobile: '+1 (202) 555-1213')
        allow(User).to receive(:exists?).with(mobile: user.mobile).and_return(true)

        subject.mobile = user.mobile

        expect(subject.valid_form?).to be false
      end
    end

    context 'when mobile is not already taken' do
      it 'is valid' do
        subject.mobile = '+1 (703) 555-1212'

        expect(subject.valid_form?).to be true
      end
    end

    context 'when mobile is same as current user' do
      it 'is valid' do
        subject.mobile = user.mobile

        expect(subject.valid_form?).to be true
      end
    end

    context 'when mobile is nil' do
      it 'does not add already taken errors' do
        subject.mobile = nil
        subject.valid?

        expect(subject.errors[:mobile].uniq).
          to eq [t('errors.messages.improbable_phone')]
        expect(subject.valid_form?).to be false
      end
    end
  end
end
