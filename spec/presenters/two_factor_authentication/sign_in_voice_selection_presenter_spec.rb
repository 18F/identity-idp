require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInVoiceSelectionPresenter do
  let(:subject) { described_class.new(configuration: phone, user: user) }
  let(:user) { build(:user) }

  describe '#info' do
    context 'when a user has a phone configuration' do
      let(:phone) { build(:phone_configuration, phone: '+1 888 867-5309') }
      it 'includes the masked the number' do
        expect(subject.info).to include('(***) ***-5309')
      end
    end
  end

  describe '#disabled?' do
    let(:phone) { build(:phone_configuration, phone: '+1 888 867-5309') }
    it { expect(subject.disabled?).to eq(false) }

    context 'voice vendor outage' do
      before do
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:voice).
          and_return(true)
      end

      it { expect(subject.disabled?).to eq(true) }
    end
  end
end
