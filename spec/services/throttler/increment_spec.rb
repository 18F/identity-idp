require 'rails_helper'

describe Throttler::Increment do
  let(:user_id) { 1 }
  let(:throttle_type) { Throttler::ThrottleTypes::IDV_ACUANT }
  let(:subject) { described_class.new(user_id, throttle_type) }
  let(:throttle) { Throttle.all.first }

  it 'creates and increments a throttle if one does not exist' do
    subject.call

    expect(throttle.attempts).to eq(1)
    expect(throttle.attempted_at).to be_present
  end

  it 'it increments a throttle if one exists' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: 1,
                    attempted_at: Time.zone.now)
    subject.call

    expect(throttle.attempts).to eq(2)
    expect(throttle.attempted_at).to be_present
  end
end
