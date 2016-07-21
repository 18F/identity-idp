require 'rails_helper'

describe UpdateUserMobileForm do
  let(:user) { build_stubbed(:user, :signed_up) }
  subject { UpdateUserMobileForm.new(user) }

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
      format: :international, normalize: :US, spaces: ' '
    )
  end

  describe 'mobile uniqueness' do
    context 'when mobile is already taken' do
      it 'is valid' do
        second_user = build_stubbed(:user, :signed_up, mobile: '+1 (202) 555-1213')
        allow(User).to receive(:exists?).with(email: 'new@gmail.com').and_return(false)
        allow(User).to receive(:exists?).with(mobile: second_user.mobile).and_return(true)

        subject.mobile = second_user.mobile

        expect(subject.valid?).to be true
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

        expect(subject.valid?).to be false
        expect(subject.errors[:mobile].uniq).
          to eq [t('errors.messages.improbable_phone')]
      end
    end
  end
end
