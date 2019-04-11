require 'rails_helper'

describe Throttler::IsThrottled do
  let(:user_id) { 1 }
  let(:throttle_type) { :idv_acuant }
  let(:subject) { described_class }
  let(:throttle) { Throttle.all.first }
  let(:max_attempts) { Figaro.env.acuant_max_attempts.to_i }
  let(:attempt_window_in_minutes) { Figaro.env.acuant_attempt_window_in_minutes.to_i }

  it 'returns throttle if throttled' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: max_attempts,
                    attempted_at: Time.zone.now)
    result = subject.call(user_id, throttle_type)

    expect(result.class).to eq(Throttle)
  end

  it 'returns nil if the attempts < max_attempts' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: max_attempts - 1,
                    attempted_at: Time.zone.now)
    result = subject.call(user_id, throttle_type)

    expect(result).to be_nil
  end

  it 'returns nil if the attempts <= max_attempts but the window is expired' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: max_attempts,
                    attempted_at: Time.zone.now - attempt_window_in_minutes.minutes)
    result = subject.call(user_id, throttle_type)

    expect(result).to be_nil
  end
end
