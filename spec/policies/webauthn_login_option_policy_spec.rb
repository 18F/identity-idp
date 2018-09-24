require 'rails_helper'

describe TwoFactorAuthentication::WebauthnPolicy do
  include WebauthnVerificationHelper

  describe '#configured?' do
    context 'with no sp' do
      let(:subject) { described_class.new(user, nil) }

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

    context 'with an sp' do
      let(:subject) { described_class.new(user, 'foo') }

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
          expect(subject.configured?).to be_falsey
        end
      end
    end
  end
end
