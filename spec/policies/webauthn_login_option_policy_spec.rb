require 'rails_helper'

describe TwoFactorAuthentication::WebauthnPolicy do
  include WebauthnVerificationHelper

  let(:subject) { described_class.new(user) }

  describe '#configured?' do
    context 'without a webauthn configured' do
      let(:user) { build(:user) }

      it { expect(subject.configured?).to be_falsey }
    end

    context 'with a webauthn configured' do
      let(:user) { create(:user) }
      before do
        create_webauthn_configuration(user)
      end

      it 'returns a truthy value' do
        expect(subject.configured?).to be_truthy
      end
    end
  end
end
