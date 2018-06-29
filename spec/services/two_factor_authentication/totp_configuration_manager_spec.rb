require 'rails_helper'

RSpec.describe TwoFactorAuthentication::TotpConfigurationManager do
  let(:subject) { described_class.new(user) }

  context 'with an authenticator app configured' do
    let(:user) { build(:user, :with_authentication_app) }

    it 'is enabled' do
      expect(subject.enabled?).to eq true
    end

    it 'is configured' do
      expect(subject.configured?).to eq true
    end

    it 'is not configurable' do
      expect(subject.configurable?).to eq false
    end

    describe '#authenticate' do
      before(:each) do
        allow(user).to receive(:authenticate_totp).with(code).and_return(true)
        allow(user).to receive(:authenticate_totp).with(bad_code).and_return(false)
      end

      let(:code) { '123456' }
      let(:bad_code) { '654321' }
      let(:long_code) { '1029384' }
      let(:short_code) { '01234' }

      it 'returns true for the right value' do
        expect(subject.authenticate(code)).to eq true
      end

      it 'returns false for everything else' do
        expect(user).to_not receive(:authenticate_totp).with(long_code)
        expect(user).to_not receive(:authenticate_totp).with(short_code)

        expect(subject.authenticate(nil)).to eq false
        expect(subject.authenticate(bad_code)).to eq false
        expect(subject.authenticate(long_code)).to eq false
        expect(subject.authenticate(short_code)).to eq false
      end
    end

    describe '#remove_configuration' do
      let(:user) { create(:user, :with_authentication_app) }

      it 'removes the uuid' do
        subject.remove_configuration
        expect(user.reload.otp_secret_key).to be_nil
      end

      it 'creates an event' do
        expect(Event).to receive(:create).with(
          user_id: user.id,
          event_type: :authenticator_disabled
        )
        subject.remove_configuration
      end
    end
  end

  context 'with no authenticator app configured' do
    let(:user) { build(:user) }

    it 'is not enabled' do
      expect(subject.enabled?).to eq false
    end

    it 'is not configured' do
      expect(subject.configured?).to eq false
    end

    it 'is configurable' do
      expect(subject.configurable?).to eq true
    end

    describe '#remove_configuration' do
      let(:user) { create(:user) }

      it 'creates no event' do
        expect(Event).to_not receive(:create)
        subject.remove_configuration
      end
    end

    describe '#save_configuration' do
      let(:user) { create(:user) }
      let(:secret) { subject.generate_secret }

      before(:each) do
        expect(user).to receive(:authenticate_totp).and_return(true)
        subject.confirm_configuration(secret, '123456')
      end

      it 'saves the configuration' do
        subject.save_configuration
        expect(user.reload.otp_secret_key).to eq secret
      end

      it 'creates an event' do
        expect(Event).to receive(:create).with(user_id: user.id, event_type: :authenticator_enabled)
        subject.save_configuration
      end
    end
  end
end
