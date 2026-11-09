require 'rails_helper'

RSpec.describe ExpireTokenExchangeRefreshTokensJob do
  subject(:job) { described_class.new }

  let(:now) { Time.zone.now }
  let(:analytics) { FakeAnalytics.new }

  before { allow(job).to receive(:analytics).and_return(analytics) }

  it 'deletes tokens whose family has passed its lifetime, keeping used tokens of live families' do
    create(:token_exchange_refresh_token, family_expires_at: now - 1.minute)
    live_used = create(
      :token_exchange_refresh_token, used_at: now - 1.hour,
                                     expires_at: now - 30.minutes
    )

    job.perform(now)

    expect(TokenExchangeRefreshToken.pluck(:id)).to eq([live_used.id])
    expect(analytics).to have_logged_event(:token_exchange_refresh_tokens_expired, deleted_count: 1)
  end
end
