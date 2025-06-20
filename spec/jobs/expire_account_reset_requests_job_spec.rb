require 'rails_helper'

RSpec.describe ExpireAccountResetRequestsJob do
  describe '#perform' do
    subject(:perform) { job.perform(now) }
    let(:job) { ExpireAccountResetRequestsJob.new }

    let(:user) { create(:user) }
    let(:user2) { create(:user) }
    let(:requested_at) { Time.zone.now - 3.days }
    let(:account_reset_request) do
      AccountResetRequest.create(
        user_id: user.id,
        requested_at: requested_at,
        request_token: SecureRandom.uuid,
        cancelled_at: nil,
        granted_at: requested_at,
        granted_token: SecureRandom.uuid,
        created_at: requested_at,
        updated_at: requested_at,
        requesting_issuer: nil,
      )
      AccountResetRequest.create(
        user_id: user2.id,
        requested_at: Time.zone.now,
        request_token: nil,
        cancelled_at: nil,
        granted_at: Time.zone.now,
        granted_token: SecureRandom.uuid,
        created_at: Time.zone.now,
        updated_at: Time.zone.now,
        requesting_issuer: nil,
      )
    end
    let(:job_analytics) { FakeAnalytics.new }
    let(:now) { Time.zone.now }

    before do
      allow(IdentityConfig.store).to receive(:account_reset_token_valid_for_days)
        .and_return(0)
      allow(Analytics).to receive(:new).and_return(job_analytics)
    end

    it 'logs the event' do
      account_reset_request

      notification_sent = perform

      expect(job_analytics).to have_logged_event(
        :account_reset_request_expired,
        count: 1,
      )
      expect(notification_sent).to eq(1)
    end

    it 'updates the correct request record' do
      expect(AccountResetRequest.count).to be(0)

      account_reset_request

      expect(AccountResetRequest.count).to be(2)

      perform

      expect(AccountResetRequest.first.cancelled_at).to_not be(nil)
      expect(AccountResetRequest.second.cancelled_at).to be(nil)
    end
  end
end
