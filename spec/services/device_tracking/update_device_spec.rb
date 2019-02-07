require 'rails_helper'

describe DeviceTracking::UpdateDevice do
  subject { described_class }
  let(:user) { create(:user) }
  let(:remote_ip) { '1.2.3.4' }
  let(:user_agent) { 'Chrome/58.0.3029.110 Safari/537.36' }
  let(:uuid) { 'abc123' }
  let(:old_timestamp) { Time.zone.now - 1.hour }
  let(:device) { create(:device, last_used_at: old_timestamp) }

  it 'updates the device' do
    expect(device.last_used_at).to eq(old_timestamp)
    subject.call(device, remote_ip)

    expect(device.last_ip).to eq(remote_ip)
    expect(device.last_used_at).to_not eq(old_timestamp)
  end
end
