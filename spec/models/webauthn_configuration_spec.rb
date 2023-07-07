require 'rails_helper'

RSpec.describe WebauthnConfiguration do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:credential_id) }
    it { is_expected.to validate_presence_of(:credential_public_key) }
  end

  let(:subject) { create(:webauthn_configuration) }

  describe '#selection_presenters' do
    context 'for a roaming authenticator' do
      it 'returns a WebauthnSelectionPresenter in an array' do
        presenters = subject.selection_presenters
        expect(presenters.count).to eq 1
        expect(presenters.first).to be_instance_of(
          TwoFactorAuthentication::WebauthnSelectionPresenter,
        )
      end
    end

    context 'for a platform authenticator' do
      it 'returns a WebauthnPlatformSelectionPresenter in an array' do
        subject.platform_authenticator = true
        presenters = subject.selection_presenters
        expect(presenters.count).to eq 1
        expect(presenters.first).to be_instance_of(
          TwoFactorAuthentication::WebauthnPlatformSelectionPresenter,
        )
      end
    end
  end

  describe 'class#selection_presenters' do
    it 'returns an empty array for an empty set' do
      expect(described_class.selection_presenters([])).to eq []
    end
  end

  describe '#mfa_enabled?' do
    let(:mfa_enabled) { subject.mfa_enabled? }

    it { expect(mfa_enabled).to be_truthy }
  end

  describe '#transports' do
    context 'with nil transports' do
      before { subject.transports = nil }

      it { expect(subject).to be_valid }
    end

    context 'with empty array transports' do
      before { subject.transports = [] }

      it { expect(subject).to be_valid }
    end

    context 'with single valid transport' do
      before { subject.transports = ['ble'] }

      it { expect(subject).to be_valid }
    end

    context 'with single invalid transport' do
      before { subject.transports = ['wrong'] }

      it { expect(subject).not_to be_valid }
    end

    context 'with multiple valid transports' do
      before { subject.transports = ['ble', 'hybrid'] }

      it { expect(subject).to be_valid }
    end

    context 'with multiple invalid transports' do
      before { subject.transports = ['wrong', 'also wrong'] }

      it { expect(subject).not_to be_valid }
    end

    context 'with multiple mixed validity transports' do
      before { subject.transports = ['ble', 'wrong'] }

      it { expect(subject).not_to be_valid }
    end
  end
end
