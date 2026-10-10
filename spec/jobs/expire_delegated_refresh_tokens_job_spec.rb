require 'rails_helper'

RSpec.describe ExpireDelegatedRefreshTokensJob do
  let(:analytics) { FakeAnalytics.new }

  subject(:job) { described_class.new }

  before { allow(job).to receive(:analytics).and_return(analytics) }

  describe '#perform' do
    let!(:live) { create(:token_exchange_refresh_token, expires_at: 1.hour.from_now) }
    let!(:just_ended) do
      create(:token_exchange_refresh_token, :rotated, expires_at: 23.hours.ago)
    end
    let!(:ended) { create(:token_exchange_refresh_token, :rotated, expires_at: 25.hours.ago) }
    let!(:ended_unused) { create(:token_exchange_refresh_token, expires_at: 2.days.ago) }
    let!(:issuance) { ended.token_exchange_token }

    it 'deletes the rows of families that ended more than a day ago and reports the count' do
      job.perform(Time.zone.now)

      expect(TokenExchangeRefreshToken.exists?(live.id)).to eq(true)
      expect(TokenExchangeRefreshToken.exists?(just_ended.id)).to eq(true)
      expect(TokenExchangeRefreshToken.exists?(ended.id)).to eq(false)
      expect(TokenExchangeRefreshToken.exists?(ended_unused.id)).to eq(false)
      expect(analytics).to have_logged_event(
        :delegated_refresh_tokens_expired,
        deleted_count: 2,
      )
    end

    it 'keeps the issuance record of a purged family' do
      job.perform(Time.zone.now)

      expect(TokenExchangeToken.exists?(issuance.id)).to eq(true)
    end
  end
end
