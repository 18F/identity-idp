require 'rails_helper'

describe DeviceTracking::CreateDevice do
  subject { described_class }
  let(:user) { create(:user) }
  let(:remote_ip) { '1.2.3.4' }
  let(:user_agent) { 'Chrome/58.0.3029.110 Safari/537.36' }
  let(:uuid) { 'abc123' }

  it 'creates a new device' do
    device = subject.call(user.id, remote_ip, user_agent, uuid)
    expect(device.cookie_uuid).to eq uuid
    expect(device.user_agent).to eq user_agent
    expect(device.last_ip).to eq remote_ip
    expect(device.last_used_at).to be_present
  end

  it 'uuid defaults to new random string if no cookie uuid is supplied' do
    device = subject.call(user.id, remote_ip, user_agent, nil)

    expect(device.cookie_uuid.length).to eq(DeviceTracking::CreateDevice::COOKIE_LENGTH)
  end
end
