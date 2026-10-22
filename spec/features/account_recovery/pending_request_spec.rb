require 'rails_helper'

RSpec.feature 'Pending account recovery request', email: true do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(2)
  end

  it 'keeps confirmation separate, shows the remaining wait on sign-in, and allows cancellation' do
    sign_in_user(user)
    visit account_recovery_start_path
    click_button t('account_recovery.start.continue')

    expect(page).to have_current_path(account_recovery_pending_path)
    expect(page).to have_content(t('account_recovery.pending.header'))
    expect(page).not_to have_css('form[action*="cancel"], a[href*="cancel"]')
    recovery_request = AccountRecoveryRequest.active_for_user(user)
    Capybara.reset_session!

    travel_to recovery_request.requested_at + 1.day do
      sign_in_user(user)

      expect(page).to have_current_path(account_recovery_pending_status_path)
      expect(page).to have_content(
        strip_tags(
          t(
            'account_recovery.pending.status.wait_html',
            waiting_period: '48 hours',
            interval: '1 day',
          ),
        ),
      )

      visit login_two_factor_options_path
      expect(page).to have_content(
        t('two_factor_authentication.account_recovery.pending_alert', app_name: APP_NAME),
      )

      visit account_recovery_pending_status_path
      click_button t('account_recovery.pending.status.cancel')

      expect(page).to have_current_path(login_two_factor_options_path)
      expect(page).to have_content(t('account_recovery.pending.cancel_success'))
      expect(page).not_to have_content(
        t('two_factor_authentication.account_recovery.pending_alert', app_name: APP_NAME),
      )
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(user.reload.phone_configurations).to be_present
      expect(ActionMailer::Base.deliveries.map(&:subject)).to include(
        t('user_mailer.account_recovery_cancelled.user_cancelled.subject', app_name: APP_NAME),
      )

      visit user_two_factor_authentication_path
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(account_path)
    end
  end

  it 'warns before authenticating, then cancels the request when an existing method is used' do
    sign_in_user(user)
    visit account_recovery_start_path
    click_button t('account_recovery.start.continue')
    recovery_request = AccountRecoveryRequest.active_for_user(user)
    Capybara.reset_session!
    reset_email

    travel_to recovery_request.requested_at + 1.day do
      sign_in_user(user)
      visit user_two_factor_authentication_path

      expect(page).to have_content(
        t('two_factor_authentication.account_recovery.pending_alert', app_name: APP_NAME),
      )

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(account_path)
      t('account_recovery.cancelled_by_mfa_html', app_name: APP_NAME).split('<br>').each do |part|
        expect(page).to have_content(strip_tags(part))
      end
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(recovery_request.cancel_reason).to eq(AccountRecoveryRequest::CANCEL_REASON_MFA_USED)

      cancellation_email = ActionMailer::Base.deliveries.find do |mail|
        mail.subject ==
          t('user_mailer.account_recovery_cancelled.mfa_used.subject', app_name: APP_NAME)
      end
      expect(cancellation_email).to be_present
      expect(cancellation_email.html_part.body).to have_content(
        t('user_mailer.account_recovery_cancelled.mfa_used.intro', app_name: APP_NAME),
      )
      expect(cancellation_email.html_part.body).to have_content(
        t('user_mailer.account_recovery_request.change_password'),
      )
    end
  end
end
