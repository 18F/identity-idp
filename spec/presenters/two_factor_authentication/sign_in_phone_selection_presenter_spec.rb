require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInPhoneSelectionPresenter do
  let(:user) { create(:user) }
  let(:configuration) { create(:phone_configuration, user: user) }
  let(:delivery_method) { nil }

  let(:presenter) do
    described_class.new(user:, configuration:, delivery_method:)
  end

  describe '#type' do
    context 'without a defined delivery method' do
      let(:delivery_method) { nil }

      it 'returns generic phone type' do
        expect(presenter.type).to eq :phone
      end
    end

    context 'with delivery method' do
      let(:delivery_method) { :sms }

      context 'with user having a single configuration' do
        it 'returns delivery method' do
          expect(presenter.type).to eq :sms
        end
      end

      context 'with user having multiple configurations' do
        let(:user) { create(:user, :with_phone) }

        it 'returns delivery method appended with configuration id' do
          expect(presenter.type).to eq "sms_#{configuration.id}".to_sym
        end
      end
    end
  end

  describe '#info' do
    context 'without a defined delivery method' do
      let(:delivery_method) { nil }

      it 'returns the correct translation for setup' do
        expect(presenter.info).to eq(
          t('two_factor_authentication.two_factor_choice_options.phone_info'),
        )
      end
    end

    context 'with sms delivery method' do
      let(:delivery_method) { :sms }

      it 'returns the correct translation for sms' do
        expect(presenter.info).to eq(
          t(
            'two_factor_authentication.login_options.sms_info_html',
            phone: configuration.masked_phone,
          ),
        )
      end
    end

    context 'with voice delivery method' do
      let(:delivery_method) { :voice }

      it 'returns the correct translation for voice' do
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
    let(:phone) { build(:phone_configuration, phone: '+1 888 867-5309') }

    context 'without a defined delivery method' do
      let(:delivery_method) { nil }

      it { expect(presenter.disabled?).to eq(false) }

      context 'all phone vendor outage' do
        before do
          allow_any_instance_of(OutageStatus).to receive(:all_phone_vendor_outage?).and_return(true)
        end

        it { expect(presenter.disabled?).to eq(true) }
      end
    end

    context 'with sms delivery method' do
      let(:delivery_method) { :sms }

      it { expect(presenter.disabled?).to eq(false) }

      context 'sms vendor outage' do
        before do
          allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).
            and_return(true)
        end

        it { expect(presenter.disabled?).to eq(true) }
      end
    end

    context 'with voice delivery method' do
      let(:delivery_method) { :voice }

      it { expect(presenter.disabled?).to eq(false) }

      context 'voice vendor outage' do
        before do
          allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:voice).
            and_return(true)
        end

        it { expect(presenter.disabled?).to eq(true) }
      end
    end
  end
end
