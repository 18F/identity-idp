require 'rails_helper'

describe DeviceTracking::LookupDeviceForUser do
  subject { described_class }
  let(:current_user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:device) { create(:device, user: current_user, cookie_uuid: device_uuid) }

  let(:device_uuid) { 'foo' }
  let(:other_uuid) { 'bar' }

  before do
    current_user
    other_user
    device
  end

  it 'returns nil if the user is found but the cookie uuid is not' do
    expect(Device.find_by(user_id: current_user.id)).to be_present

    result = subject.call(current_user.id, other_uuid)

    expect(result).to be_nil
  end

  it 'returns nil if the user is not found and the cookie uuid is found' do
    expect(Device.find_by(cookie_uuid: device_uuid)).to be_present

    result = subject.call(other_user.id, device_uuid)

    expect(result).to be_nil
  end

  it 'returns the device' do
    result = subject.call(current_user.id, device_uuid)

    expect(result).to be_present
  end
end
