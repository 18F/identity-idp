require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PhoneSelectionPresenter do
  let(:presenter) { described_class.new(phone) }

  describe '#info' do
    context 'when a user does not have a phone configuration (first time)' do
      let(:phone) { nil }
      before do
        allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(false)
      end

      it 'includes a note about choosing voice or sms' do
        expect(presenter.info).
          to include(t('two_factor_authentication.two_factor_choice_options.phone_info'))
      end

      it 'does not include a masked number' do
        expect(presenter.info).to_not include('***')
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

    it { expect(presenter.disabled?).to eq(false) }

    context 'all phone vendor outage' do
      before do
        allow_any_instance_of(VendorStatus).to receive(:all_phone_vendor_outage?).and_return(true)
      end

      it { expect(presenter.disabled?).to eq(true) }
    end
  end
end
