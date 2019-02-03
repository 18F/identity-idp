require 'rails_helper'

describe DeviceTracking::ListDevices do
  subject { described_class }
  let(:now) { Time.zone.now }
  let(:user) { create(:user) }
  let(:bad_user_id) { 0 }
  let(:device1) { create_device(1, 2) }
  let(:device2) { create_device(2, 3) }
  let(:device3) { create_device(3, 1) }

  before do
    device1
    device2
    device3
  end

  it 'returns an empty list if the device is not found' do
    result = subject.call(bad_user_id, 0, 1)

    expect(result).to eq([])
  end

  it 'returns a list containing a single most recent device' do
    result = subject.call(user.id, 0, 1)

    expect(result.size).to eq(1)
    expect(result[0].id).to eq(3)
  end

  it 'returns a list containing multiple most recent devices in order and using an offset' do
    result = subject.call(user.id, 1, 2)

    expect(result.size).to eq(2)
    expect(result[0].id).to eq(1)
    expect(result[1].id).to eq(2)
  end

  def create_device(id, ago)
    create(:device, id: id, user_id: user.id, last_ip: '4.3.2.1', last_used_at: now - ago.hour)
  end
end
