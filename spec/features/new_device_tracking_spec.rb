require 'rails_helper'

describe 'New device tracking' do
  let(:user) { create(:user, :signed_up) }

  context 'user has existing devices' do
    before do
      create(:device, user: user)
    end

    it 'sends a user notification on signin' do
      sign_in_user(user)

      expect(user.reload.devices.length).to eq 2

      device = user.devices.order(created_at: :desc).first

      expect_delivered_email_count(1)
      expect_delivered_email(
        0, {
          to: [user.email_addresses.first.email],
          subject: t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME),
          body: [device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
                 strftime('%B %-d, %Y %H:%M Eastern Time'), 'From 127.0.0.1 (IP address potentially located in United States)']
        }
      )
    end
  end

  context 'user does not have existing devices' do
    it 'should not send any notifications' do
      allow(UserMailer).to receive(:new_device_sign_in).and_call_original

      sign_in_user(user)

      expect(user.devices.length).to eq 1
      expect(UserMailer).not_to have_received(:new_device_sign_in)
    end
  end

  context 'user does not have a phone configured' do
    let(:user) { create(:user) }

    before do
      create(:device, user: user)
    end

    it 'does not send an SMS' do
      sign_in_user(user)

      expect(user.reload.devices.length).to eq 2

      device = user.devices.order(created_at: :desc).first
      expect_delivered_email_count(1)
      expect_delivered_email(
        0, {
          to: [user.email_addresses.first.email],
          subject: t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME),
          body: [device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
                 strftime('%B %-d, %Y %H:%M Eastern Time'), 'From 127.0.0.1 (IP address potentially located in United States)']
        }
      )
      expect(Telephony::Test::Message.messages.count).to eq 0
    end
  end
end
