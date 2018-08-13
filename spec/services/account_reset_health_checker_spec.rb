require 'rails_helper'

RSpec.describe AccountResetHealthChecker do
  let(:wait_period) { Figaro.env.account_reset_wait_period_days.to_i.days }
  let(:buffer_period) { 2.hours } # window buffer to allow servicing requests after 24 hours
  describe '.check' do
    subject(:summary) { AccountResetHealthChecker.check }

    context 'when there are no requests' do
      it 'returns a healthy check' do
        expect(summary.result).to eq(nil)
        expect(summary.healthy).to eq(true)
      end
    end

    context 'when a request is not serviced on time' do
      before do
        AccountResetRequest.create(id: 1,
                                   user_id: 2,
                                   requested_at: Time.zone.now - wait_period - buffer_period,
                                   request_token: 'foo')
      end

      it 'returns an unhealthy check' do
        expect(summary.healthy).to eq(false)
      end
    end

    context 'when an old request was cancelled' do
      before do
        AccountResetRequest.create(id: 1,
                                   user_id: 2,
                                   requested_at: Time.zone.now - wait_period - buffer_period,
                                   request_token: 'foo',
                                   cancelled_at: Time.zone.now)
      end

      it 'returns an unhealthy check' do
        expect(summary.healthy).to eq(true)
      end
    end

    context 'when all requests are serviced on time' do
      before do
        AccountResetRequest.create(id: 1,
                                   user_id: 2,
                                   requested_at: Time.zone.now - wait_period - buffer_period,
                                   request_token: 'foo',
                                   granted_at: Time.zone.now - buffer_period,
                                   granted_token: 'bar')
      end

      it 'returns a healthy check' do
        expect(summary.healthy).to eq(true)
      end
    end
  end
end
