require 'rails_helper'

describe DeviceTracking::FindOrCreateDevice do
  subject { described_class }

  let(:user) { create(:user, :signed_up, devices: [device].compact) }
  let(:device) { build(:device, user_id: -1) }

  context 'user signs on from an existing device' do
    it 'updates the current device' do
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

  context 'user signs in from a new device' do
    let(:new_device) { build(:device, cookie_uuid: 'abcd') }

    context 'the user has existing devices' do
      it 'adds a new new device and alerts the user' do
        expect(DeviceTracking::CreateDevice).to receive(:call).
          with(user.id, '5.5.5.5', 'agent', 'abcd').
          and_return(new_device)
        expect(DeviceTracking::AlertUserAboutNewDevice).to receive(:call).with(user, new_device)

        result = subject.call(user, 'abcd', '5.5.5.5', 'agent')

        expect(result.cookie_uuid).to eq 'abcd'
      end
    end

    context 'the user does not have any existing devices' do
      let(:device) { nil }

      it 'adds a new device and does not alert the user' do
        expect(DeviceTracking::CreateDevice).to receive(:call).
          with(user.id, '5.5.5.5', 'agent', 'abcd').
          and_return(new_device)
        expect(DeviceTracking::AlertUserAboutNewDevice).to_not receive(:call)

        result = subject.call(user, 'abcd', '5.5.5.5', 'agent')

        expect(result.cookie_uuid).to eq 'abcd'
      end
    end
  end
end
