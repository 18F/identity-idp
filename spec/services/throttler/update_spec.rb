require 'rails_helper'

describe Throttler::Update do
  let(:user_id) { 1 }
  let(:throttle_type) { :idv_acuant }
  let(:subject) { described_class }
  let(:throttle) do
    Throttle.create(
      user_id: user_id,
      throttle_type: throttle_type,
      attempts: 1,
      attempted_at: Time.zone.now,
    )
  end
  let(:analytics) { FakeAnalytics.new }

  it 'updates' do
    subject.call(throttle: throttle, attributes: { attempts: 2 }, analytics: analytics)

    expect(throttle.saved_change_to_attribute?(:attempts)).to be_truthy
  end

  it 'logs if model flips to throttled' do
    max_attempts, _attempt_window_in_minutes = Throttle.config_values(throttle_type)
    subject.call(
      throttle: throttle,
      attributes: { attempts: max_attempts + 1 },
      analytics: analytics,
    )

    expect(analytics).to have_logged_event(
      Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
      throttle_type: throttle_type.to_s,
    )
  end
end
