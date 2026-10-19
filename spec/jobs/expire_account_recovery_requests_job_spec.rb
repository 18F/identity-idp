require 'rails_helper'

RSpec.describe ExpireAccountRecoveryRequestsJob do
  let(:user) { create(:user, :fully_registered) }
  let(:now) { Time.zone.now }

  describe '#perform' do
    it 'expires a granted request whose link has lapsed' do
      recovery_request = create(
        :account_recovery_request,
        :granted,
        user: user,
        token_expires_at: now - 1.hour,
      )

      expect(described_class.new.perform(now)).to eq(1)

      recovery_request.reload
      expect(recovery_request.state).to eq(AccountRecoveryRequest::EXPIRED)
      expect(recovery_request.expired_at).to be_present
      expect(recovery_request.token_fingerprint).to be_nil
    end

    it 'leaves a granted request whose link is still valid' do
      recovery_request = create(
        :account_recovery_request,
        :granted,
        user: user,
        token_expires_at: now + 1.hour,
      )

      expect(described_class.new.perform(now)).to eq(0)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
    end

    it 'expires a verified link before password verification at the expiry boundary' do
      recovery_request = create(
        :account_recovery_request,
        :link_verified,
        user: user,
        token_expires_at: now,
      )

      expect(described_class.new.perform(now)).to eq(1)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::EXPIRED)
    end

    it 'never expires a request whose password was already verified' do
      recovery_request = create(
        :account_recovery_request,
        :password_verified,
        user: user,
        token_expires_at: now - 5.days,
      )

      expect(described_class.new.perform(now)).to eq(0)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
    end

    it 'leaves waiting requests alone' do
      recovery_request = create(:account_recovery_request, :waiting, user: user)

      expect(described_class.new.perform(now)).to eq(0)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
    end

    it 'frees the user to create a new request' do
      create(
        :account_recovery_request,
        :granted,
        user: user,
        token_expires_at: now - 1.hour,
      )

      described_class.new.perform(now)

      expect(AccountRecoveryRequest.active_for_user(user)).to be_nil
      expect do
        create(:account_recovery_request, :waiting, user: user)
      end.to change { AccountRecoveryRequest.count }.by(1)
    end

    it 'logs the number of expired requests' do
      stub_analytics
      job = described_class.new
      allow(job).to receive(:analytics).and_return(@analytics)
      create(
        :account_recovery_request,
        :granted,
        user: user,
        token_expires_at: now - 1.hour,
      )

      job.perform(now)

      expect(@analytics).to have_logged_event(:account_recovery_expired, count: 1)
    end

    it 'does not touch legacy account reset requests' do
      AccountResetRequest.create!(
        user: user,
        requested_at: now - 10.days,
        request_token: SecureRandom.uuid,
      )

      expect { described_class.new.perform(now) }
        .to_not change { AccountResetRequest.where.not(cancelled_at: nil).count }
    end
  end
end
