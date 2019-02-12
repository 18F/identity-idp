require 'rails_helper'

describe DeviceTracking::CreateDevice do
  subject { described_class }
  let(:user) { create(:user) }
  let(:remote_ip) { '1.2.3.4' }
  let(:user_agent) { 'Chrome/58.0.3029.110 Safari/537.36' }
  let(:uuid) { 'abc123' }
  let(:device) { Device.all.first }

  it 'creates a new device' do
    subject.call(user.id, remote_ip, user_agent, uuid)

    expect_device_attribute(:cookie_uuid, uuid)
    expect_device_attribute(:user_agent, user_agent)
    expect_device_attribute(:last_ip, remote_ip)
    expect(device.last_used_at).to be_present
  end

  it 'uuid defaults to new random string if no cookie uuid is supplied' do
    subject.call(user.id, remote_ip, user_agent, nil)

    expect(Device.all.first.cookie_uuid.length).to eq(DeviceTracking::CreateDevice::COOKIE_LENGTH)
  end

  def expect_device_attribute(key, val)
    expect(device.send(key)).to eq(val)
  end
end
