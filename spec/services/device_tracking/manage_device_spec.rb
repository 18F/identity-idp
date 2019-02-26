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
  end
end
