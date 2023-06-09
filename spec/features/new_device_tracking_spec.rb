require 'rails_helper'

RSpec.describe 'New device tracking' do
  include SamlAuthHelper

  let(:user) { create(:user, :fully_registered) }

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
        to: [user.email_addresses.first.email],
        subject: t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME),
        body: [device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
               strftime('%B %-d, %Y %H:%M Eastern Time'),
               'From 127.0.0.1 (IP address potentially located in United States)'],
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

  context 'user signs up and confirms email in a different browser' do
    let(:user) { build(:user) }

    it 'does not send an email' do
      perform_in_browser(:one) do
        visit_idp_from_sp_with_ial1(:oidc)
        sign_up_user_from_sp_without_confirming_email(user.email)
      end

      perform_in_browser(:two) do
        expect do
          confirm_email_in_a_different_browser(user.email)
        end.not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end
end
