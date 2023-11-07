require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInSmsSelectionPresenter do
  let(:subject) { described_class.new(configuration: phone, user: user) }
  let(:user) { build(:user) }
  let(:configuration) { create(:phone_configuration, user: user) }
  let(:presenter) do
    described_class.new(user: user, configuration: configuration)
  end

  describe '#type' do
    context 'when a user has only one phone configuration' do
      let(:user) { create(:user, :with_phone) }
      let(:phone) { MfaContext.new(user).phone_configurations.first }

      it 'returns sms' do
        expect(subject.type).to eq 'sms'
      end
    end

    context 'when a user has more than one phone configuration' do
      let(:user) { create(:user, :with_phone) }
      let(:phone) do
        record = create(:phone_configuration, user: user)
        user.reload
        record
      end

      it 'returns sms:id' do
        expect(subject.type).to eq "sms_#{phone.id}"
      end
    end
  end

  describe '#info' do
    it 'raises with missing translation' do
      expect(presenter.info).to eq(
        t(
          'two_factor_authentication.login_options.sms_info_html',
          phone: configuration.masked_phone,
        )
      )
    end
  end

  describe '#disabled?' do
    let(:phone) { build(:phone_configuration, phone: '+1 888 867-5309') }
    it { expect(subject.disabled?).to eq(false) }

    context 'sms vendor outage' do
      before do
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
      end

      it { expect(subject.disabled?).to eq(true) }
    end
  end
end
