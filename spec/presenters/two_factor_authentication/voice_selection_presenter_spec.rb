require 'rails_helper'

describe TwoFactorAuthentication::VoiceSelectionPresenter do
  let(:subject) { described_class.new(configuration: phone) }

  describe '#type' do
    context 'when a user has only one phone configuration' do
      let(:user) { create(:user, :with_phone) }
      let(:phone) { MfaContext.new(user).phone_configurations.first }

      it 'returns voice' do
        expect(subject.type).to eq 'voice'
      end
    end

    context 'when a user has more than one phone configuration' do
      let(:user) { create(:user, :with_phone) }
      let(:phone) do
        record = create(:phone_configuration, user: user)
        user.reload
        record
      end

      it 'returns voice:id' do
        expect(subject.type).to eq "voice_#{phone.id}"
      end
    end
  end

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
        allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:voice).
          and_return(true)
      end

      it { expect(subject.disabled?).to eq(true) }
    end
  end
end
