require 'rails_helper'

describe TwoFactorAuthentication::VoiceSelectionPresenter do
  let(:subject) { described_class.new(phone) }

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
end
