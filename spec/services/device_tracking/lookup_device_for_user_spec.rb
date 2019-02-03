require 'rails_helper'

describe DeviceTracking::LookupDeviceForUser do
  subject { described_class }
  let(:user) { create(:user) }
  let(:bad_user_id) { 0 }
  let(:device) { create(:device) }
  let(:good_uuid) { 'foo' }
  let(:good_user_id) { 1 }
  let(:bad_uuid) { 'bar' }
  let(:bad_user_id) { 2 }

  before do
    user
    device
  end

  it 'returns nil if the user is found but the cookie uuid is not' do
    expect(Device.find_by(user_id: good_user_id)).to be_present
    result = subject.call(good_user_id, bad_uuid)

    expect(result).to be_nil
  end

  it 'returns nil if the user is not found and the cookie uuid is found' do
    expect(Device.find_by(cookie_uuid: good_uuid)).to be_present
    result = subject.call(bad_user_id, good_uuid)

    expect(result).to be_nil
  end

  it 'returns the device' do
    result = subject.call(good_user_id, good_uuid)

    expect(result).to be_present
  end
end
