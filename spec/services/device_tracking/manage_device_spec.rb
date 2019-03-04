require 'rails_helper'

describe DeviceTracking::ManageDevice do
  subject { described_class }

  let(:user) { create(:user, :signed_up) }

  context 'user signs on from an existing device' do
    before do
      create(:device, user: user)
    end

    it 'updates a current device' do
      old_last_used_at = user.devices.first.last_used_at
      result = subject.call(
        user,
        user.devices.first.cookie_uuid,
        user.devices.first.user_agent,
        user.devices.first.last_ip,
      )
      expect(result.last_used_at).not_to eq old_last_used_at
    end

    it 'adds a new device and alerts the user' do
      # the test object does not contain language as a method (was added by us)
      allow_any_instance_of(Geocoder::Result::Test).to receive(:language=)
      expect(UserMailer).to receive(:new_device_sign_in).and_call_original
      expect(SmsNewDeviceSignInNotifierJob).to receive(:perform_now)

      device = create(:device)
      expect(DeviceTracking::CreateDevice).to receive(:call) { device }

      old_cookie_uuid = user.devices.first.cookie_uuid
      result = subject.call(user, 'abcd', 'agent', 'ip')

      expect(result.cookie_uuid).not_to eq old_cookie_uuid
    end
  end
end
