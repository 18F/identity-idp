require 'rails_helper'

RSpec.describe ExpireAccountResetRequestsJob do
  include AccountResetHelper
  describe '#perform' do
    subject(:perform) { job.perform(now) }
    let(:job) { ExpireAccountResetRequestsJob.new }
    let(:job_analytics) { FakeAnalytics.new }
    let(:now) { Time.zone.now }

    before do
      allow(IdentityConfig.store).to receive(:account_reset_token_valid_for_days)
        .and_return(0)
      allow(Analytics).to receive(:new).and_return(job_analytics)
    end

    it 'it expires requests with expired grant tokens and ignores valid grant tokens' do
      user = create(:user, :fully_registered, confirmed_at: Time.zone.now.round)
      create_account_reset_request_for(user)
      grant_request(user)

      travel_to(Time.zone.now + 3.days) do
        user2 = create(
          :user, :fully_registered,
          confirmed_at: Time.zone.now.round
        )
        create_account_reset_request_for(user2)
        grant_request(user2)

        notification_sent = perform

        expect(job_analytics).to have_logged_event(
          :account_reset_request_expired,
          count: 1,
        )
        expect(notification_sent).to eq(1)

        expect(AccountResetRequest.first.expired_at).to_not be(nil)
        expect(AccountResetRequest.second.expired_at).to be(nil)
      end
    end
  end
end
