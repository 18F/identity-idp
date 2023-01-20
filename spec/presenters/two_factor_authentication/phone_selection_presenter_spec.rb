require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PhoneSelectionPresenter do
  let(:user_without_mfa) { create(:user) }
  let(:user_with_mfa) { create(:user, :with_phone) }
  let(:presenter_with_mfa) { described_class.new(configuration: phone, user: user_with_mfa) }
  let(:presenter_without_mfa) { described_class.new(configuration: phone, user: user_without_mfa) }

  describe '#info' do
    context 'when a user does not have a phone configuration (first time)' do
      let(:phone) { nil }

      it 'includes a note about choosing voice or sms' do
        expect(presenter_without_mfa.info).
          to include(t('two_factor_authentication.two_factor_choice_options.phone_info'))
      end

      it 'does not include a masked number' do
        expect(presenter_without_mfa.info).to_not include('***')
      end

      context 'when VOIP numbers are blocked' do
        before do
          allow(IdentityConfig.store).to receive(:voip_block).and_return(true)
        end
      end
    end
  end

  describe '#disabled?' do
    let(:phone) { build(:phone_configuration, phone: '+1 888 867-5309') }

    it { expect(presenter_without_mfa.disabled?).to eq(false) }

    context 'all phone vendor outage' do
      before do
        allow_any_instance_of(VendorStatus).to receive(:all_phone_vendor_outage?).and_return(true)
      end

      it { expect(presenter_without_mfa.disabled?).to eq(true) }
    end
  end

  describe '#mfa_configuration' do
    let(:phone) { nil }
    it 'returns an empty string when user has not configured this authenticator' do
      expect(presenter_without_mfa.mfa_configuration_description).to eq('')
    end
    it 'returns an # added when user has configured this authenticator' do
      expect(presenter_with_mfa.mfa_configuration_description).to eq(
        t(
          'two_factor_authentication.two_factor_choice_options.configurations_added',
          count: 1,
        ),
      )
    end

    it 'does not include a note to select an additional mfa on additional setup' do
      expect(presenter_with_mfa.info).
        to eq(t('two_factor_authentication.two_factor_choice_options.phone_info'))
    end
  end
end
