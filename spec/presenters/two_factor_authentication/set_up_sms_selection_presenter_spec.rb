require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpSmsSelectionPresenter do
  let(:subject) { described_class.new(configuration: phone, user: user) }
  let(:user) { build(:user) }

  describe '#type' do
    context 'when a user has only one phone configuration' do
      let(:user) { create(:user, :with_phone) }
      let(:phone) { MfaContext.new(user).phone_configurations.first }

      it 'returns sms' do
        expect(subject.type).to eq 'sms'
      end
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
