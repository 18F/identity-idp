require 'rails_helper'

describe Throttler::IsThrottled do
  let(:user_id) { 1 }
  let(:throttle_type) { :idv_acuant }
  let(:subject) { described_class.new(user_id, throttle_type) }
  let(:throttle) { Throttle.all.first }
  let(:max_attempts) { 3 }
  let(:attempt_window_in_minutes) { 5 }

  it 'returns throttle if throttled' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: max_attempts,
                    attempted_at: Time.zone.now)
    result = subject.call(max_attempts, attempt_window_in_minutes)

    expect(result.class).to eq(Throttle)
  end

  it 'returns nil if the attempts < max_attempts' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: max_attempts - 1,
                    attempted_at: Time.zone.now)
    result = subject.call(max_attempts, attempt_window_in_minutes)

    expect(result).to be_nil
  end

  it 'returns nil if the attempts <= max_attempts but the window is expired' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: max_attempts,
                    attempted_at: Time.zone.now - 6.minutes)
    result = subject.call(max_attempts, attempt_window_in_minutes)

    expect(result).to be_nil
  end
end
