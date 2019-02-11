require 'rails_helper'

describe DeviceTracking::ListDevices do
  subject { described_class }

  let(:current_user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:devices) do
    [
      create(:device, user: current_user, last_used_at: 2.hours.ago),
      create(:device, user: current_user, last_used_at: 3.hours.ago),
      create(:device, user: current_user, last_used_at: 1.hour.ago),
    ]
  end

  before do
    # Memoize records to run creates for specs that query the table
    current_user
    other_user
    devices
  end

  it 'returns an empty list if the device is not found' do
    result = subject.call(other_user.id, 0, 1)

    expect(result).to eq([])
  end

  it 'returns a list containing a single most recent device' do
    result = subject.call(current_user.id, 0, 1)

    expect(result.size).to eq(1)
    expect(result[0].id).to eq(devices[2].id)
  end

  it 'returns a list containing multiple most recent devices in order and using an offset' do
    result = subject.call(current_user.id, 1, 2)

    expect(result.size).to eq(2)
    expect(result[0].id).to eq(devices[0].id)
    expect(result[1].id).to eq(devices[1].id)
  end
end
