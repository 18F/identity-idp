require 'rails_helper'

describe Analytics do
  let(:fake_analytics) { FakeAnalytics.new }

  describe '#idv_gpo_address_letter_requested' do
    it 'logs letter requested with enqueued at' do
      enqueued_at = Time.zone.now
      fake_analytics.idv_gpo_address_letter_requested(enqueued_at: enqueued_at)

      expect(fake_analytics).to have_logged_event(
        'IdV: USPS address letter requested',
        enqueued_at: enqueued_at,
      )
    end
  end
end
