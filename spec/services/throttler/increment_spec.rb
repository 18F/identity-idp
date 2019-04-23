require 'rails_helper'

describe Throttler::Increment do
  let(:user_id) { 1 }
  let(:throttle_type) { :idv_acuant }
  let(:subject) { described_class }
  let(:throttle) { Throttle.all.first }

  it 'creates and increments a throttle if one does not exist' do
    subject.call(user_id, throttle_type)

    expect(throttle.attempts).to eq(1)
    expect(throttle.attempted_at).to be_present
  end

  it 'it increments a throttle if one exists' do
    Throttle.create(user_id: user_id,
                    throttle_type: throttle_type,
                    attempts: 1,
                    attempted_at: Time.zone.now)
    subject.call(user_id, throttle_type)

    expect(throttle.attempts).to eq(2)
    expect(throttle.attempted_at).to be_present
  end
end
