require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpPhoneSelectionPresenter do
  let(:user) { create(:user) }
  let(:presenter) { described_class.new(user:) }

  describe '#info' do
    it 'includes a note about choosing voice or sms' do
      expect(presenter.info).to eq(
        t('two_factor_authentication.two_factor_choice_options.phone_info'),
      )
    end
  end

  describe '#disabled?' do
    subject(:disabled) { presenter.disabled? }

    it { expect(disabled).to eq(false) }

    context 'all phone vendor outage' do
      before do
        allow_any_instance_of(OutageStatus).to receive(:all_phone_vendor_outage?).and_return(true)
      end

      it { expect(disabled).to eq(true) }
    end
  end

  describe '#mfa_configuration' do
    subject(:mfa_configuration_description) { presenter.mfa_configuration_description }

    context 'user without configured authenticator' do
      let(:user) { create(:user) }

      it 'returns an empty string' do
        expect(mfa_configuration_description).to eq('')
      end
    end

    context 'user with configured authenticator' do
      let(:user) { create(:user, :with_phone) }

      it 'returns text with number of added authenticators' do
        expect(mfa_configuration_description).to eq(
          t(
            'two_factor_authentication.two_factor_choice_options.configurations_added',
            count: 1,
          ),
        )
      end
    end
  end

  describe '#phishing_resistant?' do
    subject(:phishing_resistant) { presenter.phishing_resistant? }

    it { expect(phishing_resistant).to eq(false) }
  end

  describe '#visible?' do
    subject(:visible) { presenter.visible? }

    it 'defaults to the result of the base class' do
      expect(visible).to eq(TwoFactorAuthentication::SetUpSelectionPresenter.new(user:).visible?)
    end

    context 'with phone option configured to be hidden during signup' do
      before do
        allow(IdentityConfig.store).to receive(:hide_phone_mfa_signup).and_return(true)
      end

      it { expect(visible).to eq(false) }
    end
  end
end
