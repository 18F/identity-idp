require 'rails_helper'

describe DeviceTracking::ListDeviceEvents do
  subject { described_class }

  let(:current_user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:current_device) { create(:device, user: current_user) }
  let(:other_device) { create(:device) }

  let(:events) do
    [
      create(:event, user: current_user, device: current_device, created_at: 2.hours.ago),
      create(:event, user: current_user, device: current_device, created_at: 3.hours.ago),
      create(:event, user: current_user, device: current_device, created_at: 1.hour.ago),
    ]
  end

  before do
    # Memoize records to run creates for specs that query the table
    current_user
    other_user
    current_device
    other_device
    events
  end

  it 'returns an empty list if the device is not found' do
    result = subject.call(current_user.id, other_device.id, 0, 1)

    expect(result).to eq([])
  end

  it 'returns an empty list if the device is found but the user is not' do
    result = subject.call(other_user.id, current_device.id, 0, 1)

    expect(result).to eq([])
  end

  it 'returns a list containing a single most recent event' do
    result = subject.call(current_user.id, current_device.id, 0, 1)

    expect(result.size).to eq(1)
    expect(result[0].id).to eq(events[2].id)
  end

  it 'returns a list containing multiple most recent events in order and using an offset' do
    result = subject.call(current_user.id, current_device.id, 1, 2)

    expect(result.size).to eq(2)
    expect(result[0].id).to eq(events[0].id)
    expect(result[1].id).to eq(events[1].id)
  end
end
