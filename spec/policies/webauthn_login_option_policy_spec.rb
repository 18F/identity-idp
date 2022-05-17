require 'rails_helper'

describe TwoFactorAuthentication::WebauthnPolicy do
  include WebAuthnHelper

  let(:subject) { described_class.new(user) }

  describe '#configured?' do
    context 'without a webauthn configured' do
      let(:user) { build(:user) }

      it { expect(subject.configured?).to be_falsey }
    end

    context 'with a webauthn configured' do
      let(:user) { create(:user) }
      before do
        create(
          :webauthn_configuration,
          user: user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )
      end

      it 'returns a truthy value' do
        expect(subject.configured?).to be_truthy
      end
    end
  end

  describe '#roaming_enabled?' do
    context 'without a webauthn configured' do
      let(:user) { build(:user) }

      it { expect(subject.roaming_enabled?).to be_falsey }
    end

    context 'with a roaming webauthn configured' do
      let(:user) { create(:user) }
      before do
        create(
          :webauthn_configuration,
          user: user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
          platform_authenticator: false,
        )
      end

      it 'returns a truthy value' do
        expect(subject.roaming_enabled?).to be_truthy
      end
    end
  end
end
