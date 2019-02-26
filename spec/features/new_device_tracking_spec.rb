require 'rails_helper'

describe 'New device tracking' do
  let(:user) { create(:user, :signed_up) }

  context 'user has existing devices' do
    before do
      create(:device, user: user)
    end

    it 'sends a user notification on signin' do
      allow(UserMailer).to receive(:new_device_sign_in).and_call_original
      allow(SmsNewDeviceSignInNotifierJob).to receive(:perform_now)

      sign_in_user(user)

      expect(user.reload.devices.length).to eq 2

      device = user.devices.order(created_at: :desc).first

      expect(UserMailer).to have_received(:new_device_sign_in).
        with(
          user.email,
          device.last_used_at.strftime('%B %-d, %Y %H:%M'),
          'From United States (IP address: 127.0.0.1)',
        )
      expect(SmsNewDeviceSignInNotifierJob).to have_received(:perform_now).
        with(phone: user.phone_configurations.first.phone)
    end
  end

  context 'user does not have existing devices' do
    it 'should not send any notifications' do
      allow(UserMailer).to receive(:new_device_sign_in).and_call_original
      allow(SmsNewDeviceSignInNotifierJob).to receive(:perform_now)

      sign_in_user(user)

      expect(user.devices.length).to eq 1
      expect(UserMailer).not_to have_received(:new_device_sign_in)
      expect(SmsNewDeviceSignInNotifierJob).not_to have_received(:perform_now)
    end
  end

  context 'user does not have a phone configured' do
    let(:user) { create(:user) }

    before do
      create(:device, user: user)
    end

    it 'does not send an SMS' do
      allow(UserMailer).to receive(:new_device_sign_in).and_call_original
      allow(SmsNewDeviceSignInNotifierJob).to receive(:perform_now)

      sign_in_user(user)

      expect(user.reload.devices.length).to eq 2

      device = user.devices.order(created_at: :desc).first

      expect(UserMailer).to have_received(:new_device_sign_in).
        with(
          user.email,
          device.last_used_at.strftime('%B %-d, %Y %H:%M'),
          'From United States (IP address: 127.0.0.1)',
        )
      expect(SmsNewDeviceSignInNotifierJob).to_not have_received(:perform_now)
    end
  end
end
