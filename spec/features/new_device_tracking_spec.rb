require 'rails_helper'

RSpec.describe 'New device tracking' do
  include SamlAuthHelper

  let(:user) { create(:user, :fully_registered) }

  context 'user has existing devices' do
    let(:user) { create(:user, :with_authenticated_device) }

    it 'sends a user notification on signin' do
      sign_in_live_with_2fa(user)

      expect(user.reload.devices.length).to eq 2
      expect_delivered_email_count(1)
      expect_delivered_email(
        to: [user.email_addresses.first.email],
        subject: t('user_mailer.new_device_sign_in_after_2fa.subject', app_name: APP_NAME),
      )
    end

    it 'sends all notifications for an expired sign-in session' do
      allow(IdentityConfig.store).to receive(:new_device_alert_delay_in_minutes).and_return(5)
      allow(IdentityConfig.store).to receive(:session_timeout_warning_seconds).and_return(15)

      sign_in_user(user)

      # Notified after expired delay for successful email password, but incomplete MFA
      travel_to 6.minutes.from_now do
        CreateNewDeviceAlertJob.new.perform(Time.zone.now)
        open_last_email
        email_page = Capybara::Node::Simple.new(current_email.default_part_body)
        expect(email_page).to have_css(
          '.usa-table td.font-family-mono',
          count: 1,
          text: t('user_mailer.new_device_sign_in_attempts.events.sign_in_before_2fa'),
        )
      end

      reset_email

      travel_to 16.minutes.from_now do
        visit root_url
        expect(page).to have_current_path(new_user_session_path)
        sign_in_user(user)
      end

      # Notified after session expired, user returned for another successful email password, no MFA
      travel_to 22.minutes.from_now do
        CreateNewDeviceAlertJob.new.perform(Time.zone.now)
        open_last_email
        email_page = Capybara::Node::Simple.new(current_email.default_part_body)
        expect(email_page).to have_css(
          '.usa-table td.font-family-mono',
          count: 1,
          text: t('user_mailer.new_device_sign_in_attempts.events.sign_in_before_2fa'),
        )
      end

      reset_email

      # Notified after session expired, user returned for successful email password and MFA
      travel_to 38.minutes.from_now do
        visit root_url
        expect(page).to have_current_path(new_user_session_path)

        # Regression: LG-13221: Ensure that the successful authentication email lists failed MFA.
        sign_in_user(user)
        fill_in t('components.one_time_code_input.label'), with: '000000'
        click_submit_default
        fill_in_code_with_last_phone_otp
        click_submit_default

        open_last_email
        email_page = Capybara::Node::Simple.new(current_email.default_part_body)
        expect(email_page).to have_css('.usa-table td.font-family-mono', count: 3)
        expect(email_page).to have_content(
          t('user_mailer.new_device_sign_in_attempts.events.sign_in_before_2fa'),
        )
        expect(email_page).to have_content(
          t('user_mailer.new_device_sign_in_attempts.events.sign_in_unsuccessful_2fa'),
        )
        expect(email_page).to have_content(
          t('user_mailer.new_device_sign_in_attempts.events.sign_in_after_2fa'),
        )
      end
    end

    context 'from existing device' do
      before do
        Capybara.current_session.driver.browser.current_session.cookie_jar[:device] =
          user.devices.first.cookie_uuid
      end

      it 'does not send a user notification on sign in' do
        sign_in_live_with_2fa(user)

        expect(user.reload.devices.length).to eq 1
        expect_delivered_email_count(0)
      end
    end

    context 'when reauthenticating' do
      it 'does not send a second user notification' do
        # Regression: LG-13419: Reset new-device session value after fully authenticating, so that
        # reauthentication doesn't consider the device as new and send another notification.
        sign_in_live_with_2fa(user)
        expect_delivered_email_count(1)

        expire_reauthn_window

        within('.sidenav') { click_on t('account.navigation.add_phone_number') }
        expect(page).to have_current_path(login_two_factor_options_path)
        click_on t('forms.buttons.continue')
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect_delivered_email_count(1)
      end
    end

    context 'authenticating with piv' do
      let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

      it 'sends a user notification on signin' do
        visit new_user_session_path
        click_on t('account.login.piv_cac')
        fill_in_piv_cac_credentials_and_submit(user)

        expect_delivered_email_count(1)
        expect_delivered_email(
          to: [user.email_addresses.first.email],
          subject: t('user_mailer.new_device_sign_in_after_2fa.subject', app_name: APP_NAME),
        )
      end

      context 'when reauthenticating' do
        it 'does not send a second user notification' do
          visit new_user_session_path
          click_on t('account.login.piv_cac')
          fill_in_piv_cac_credentials_and_submit(user)

          expire_reauthn_window

          within('.sidenav') { click_on t('account.navigation.add_phone_number') }
          expect(page).to have_current_path(login_two_factor_options_path)
          click_on t('forms.buttons.continue')
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect_delivered_email_count(1)
        end
      end
    end

    context 'authenticating after new account creation from the same device' do
      let(:user) do
        user = sign_up_and_2fa_ial1_user
        click_on t('links.sign_out')
        user
      end

      before do
        user
        reset_email
      end

      it 'does not send a second user notification' do
        visit new_user_session_path
        sign_in_live_with_2fa(user)

        expect_delivered_email_count(0)
      end
    end

    context 'reauthenticating after new account creation' do
      before do
        sign_up_and_2fa_ial1_user
        reset_email
        expire_reauthn_window
      end

      it 'does not send a new device sign-in notification' do
        within('.sidenav') { click_on t('account.navigation.add_phone_number') }
        expect(page).to have_current_path(login_two_factor_options_path)
        click_on t('forms.buttons.continue')
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect_delivered_email_count(0)
      end
    end
  end

  context 'user does not have existing devices' do
    it 'should not send any notifications' do
      sign_in_user(user)

      expect(user.devices.length).to eq 1
      expect_delivered_email_count(0)
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
