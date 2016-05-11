require 'rails_helper'

describe TwoFactorSetupForm do
  let(:user) { create(:user, :signed_up) }
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

  def format_phone(mobile)
    mobile.phony_formatted(
      format: :international, normalize: :US, spaces: ' ')
  end

  describe 'mobile uniqueness' do
    context 'when mobile is already taken' do
      it 'is not valid' do
        second_user = create(:user, :signed_up, mobile: '+1 (202) 555-1213')

        subject.mobile = second_user.mobile
        subject.valid?

        expect(subject.errors[:mobile]).to eq [t('errors.messages.taken')]
      end
    end

    context 'when mobile is not already taken' do
      it 'is valid' do
        subject.mobile = '+1 (703) 555-1212'

        expect(subject.valid?).to be true
      end
    end

    context 'when mobile is same as current user' do
      it 'is valid' do
        subject.mobile = user.mobile

        expect(subject.valid?).to be true
      end
    end

    context 'when mobile is nil' do
      it 'does not add already taken errors' do
        subject.mobile = nil
        subject.valid?

        expect(subject.errors[:mobile].uniq).
          to eq [t('errors.messages.improbable_phone')]
      end
    end
  end
end
