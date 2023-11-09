require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInPhoneSelectionPresenter do
  let(:user) { create(:user, :with_phone) }
  let(:configuration) { create(:phone_configuration, user: user) }

  let(:presenter) do
    described_class.new(user: user, configuration: configuration, method: 'phone')
  end

  describe '#type' do
    it 'returns phone appended with configuration id' do
      expect(presenter.type).to eq "phone_#{configuration.id}"
    end
  end

  describe '#info' do
    it 'raises with missing translation' do
      expect(presenter.info).to eq(
        t('two_factor_authentication.two_factor_choice_options.phone_info'),
      )
    end
    context('with sms method') do
      let(:presenter) do
        described_class.new(user: user, configuration: configuration, method: 'sms')
      end
      it('returns the correct translation for sms') do
        expect(presenter.info).to eq(
          t(
            'two_factor_authentication.login_options.sms_info_html',
            phone: configuration.masked_phone,
          ),
        )
      end
    end
    context('with voice method') do
      let(:presenter) do
        described_class.new(user: user, configuration: configuration, method: 'voice')
      end
      it('returns the correct translation for voice') do
        expect(presenter.info).to eq(
          t(
            'two_factor_authentication.login_options.voice_info_html',
            phone: configuration.masked_phone,
          ),
        )
      end
    end
  end

  describe '#disabled?' do
    let(:user_without_mfa) { create(:user) }
    let(:phone) { build(:phone_configuration, phone: '+1 888 867-5309') }
    let(:presenter_without_mfa) do
      described_class.new(configuration: phone, user: user_without_mfa, method: 'sms')
    end
    it { expect(presenter_without_mfa.disabled?).to eq(false) }

    context 'all phone vendor outage' do
      before do
        allow_any_instance_of(OutageStatus).to receive(:all_phone_vendor_outage?).and_return(true)
      end

      it { expect(presenter_without_mfa.disabled?).to eq(true) }
    end
  end
end
