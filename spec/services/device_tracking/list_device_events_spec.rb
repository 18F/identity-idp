require 'rails_helper'

describe DeviceTracking::ListDeviceEvents do
  subject { described_class }
  let(:now) { Time.zone.now }
  let(:user) { create(:user, id: 1) }
  let(:bad_user_id) { 0 }
  let(:good_user_id) { 1 }
  let(:device) { create(:device) }
  let(:bad_device_id) { 0 }
  let(:good_device_id) { 1 }
  let(:event1) { create_event(1, 2) }
  let(:event2) { create_event(2, 3) }
  let(:event3) { create_event(3, 1) }

  before do
    user
    device
    event1
    event2
    event3
  end

  it 'returns an empty list if the device is not found' do
    result = subject.call(good_user_id, bad_device_id, 0, 1)

    expect(result).to eq([])
  end

  it 'returns an empty list if the device is found but the user is not' do
    result = subject.call(bad_user_id, good_device_id, 0, 1)

    expect(result).to eq([])
  end

  it 'returns a list containing a single most recent event' do
    result = subject.call(good_user_id, good_device_id, 0, 1)

    expect(result.size).to eq(1)
    expect(result[0].id).to eq(3)
  end

  it 'returns a list containing multiple most recent events in order and using an offset' do
    result = subject.call(good_user_id, good_device_id, 1, 2)

    expect(result.size).to eq(2)
    expect(result[0].id).to eq(1)
    expect(result[1].id).to eq(2)
  end

  def create_event(id, ago)
    create(:event, id: id, user_id: 1, device_id: 1, ip: '4.3.2.1', created_at: now - ago.hour)
  end
end
