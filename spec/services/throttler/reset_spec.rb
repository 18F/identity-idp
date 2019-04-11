require 'rails_helper'

describe Throttler::Reset do
  let(:user_id) { 1 }
  let(:throttle_type) { :idv_acuant }
  let(:max_attempts) { 3 }
  let(:subject) { described_class }
  let(:throttle) { Throttle.all.first }

  it 'resets attempt count to 0' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: max_attempts,
                    attempted_at: Time.zone.now)
    subject.call(user_id, throttle_type)

    expect(throttle.attempts).to eq(0)
  end
end
