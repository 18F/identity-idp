require 'rails_helper'

RSpec.describe ExpireAccountResetRequestsJob do
  describe '#perform' do
    subject(:perform) { job.perform(now) }
    let(:job) { ExpireAccountResetRequestsJob.new }

    let(:user) { create(:user) }
    let(:user2) { create(:user) }
    let(:expired_granted_at) { Time.zone.now - 3.days }
    let(:account_reset_request) do
      AccountResetRequest.create(
        user: user,
        granted_at: expired_granted_at,
      )
      AccountResetRequest.create(
        user: user2,
        granted_at: expired_granted_at,
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
        'Account Reset: expired',
      )
      expect(notification_sent).to eq(2)
    end

    it 'updates the request record' do
      expect(AccountResetRequest.count).to be(0)

      account_reset_request

      expect(AccountResetRequest.count).to be(2)

      perform

      expect(AccountResetRequest.last.cancelled_at).to_not be(nil)
    end
  end
end
