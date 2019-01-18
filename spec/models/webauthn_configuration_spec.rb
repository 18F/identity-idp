require 'rails_helper'

describe WebauthnConfiguration do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:credential_id) }
    it { is_expected.to validate_presence_of(:credential_public_key) }
  end

  let(:subject) { create(:webauthn_configuration) }

  describe '#selection_presenters' do
    it 'returns a WebauthnSelectionPresenter in an array' do
      presenters = subject.selection_presenters
      expect(presenters.count).to eq 1
      expect(presenters.first).to be_instance_of(
        TwoFactorAuthentication::WebauthnSelectionPresenter,
      )
    end
  end

  describe 'class#selection_presenters' do
    it 'returns an empty array for an empty set' do
      expect(described_class.selection_presenters([])).to eq []
    end
  end

  describe '#mfa_enabled?' do
    let(:mfa_enabled) { subject.mfa_enabled? }
    context 'when webauthn enabled' do
      before(:each) do
        allow(FeatureManagement).to receive(:webauthn_enabled?).and_return(true)
      end

      it { expect(mfa_enabled).to be_truthy }
    end

    context 'when webauthn not enabled' do
      before(:each) do
        allow(FeatureManagement).to receive(:webauthn_enabled?).and_return(false)
      end

      it { expect(mfa_enabled).to be_falsey }
    end
  end
end
