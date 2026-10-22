require 'rails_helper'

RSpec.feature 'Pending account recovery request' do
  it 'offers existing MFA on sign-in and links to the recovery status and cancellation page' do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(2)
    user = create(:user, :fully_registered)

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

      expect(page).to have_current_path(login_two_factor_options_path)
      expect(page).not_to have_link(t('two_factor_authentication.account_reset.link'))
      click_link t('two_factor_authentication.account_recovery.pending_link')

      expect(page).to have_current_path(account_recovery_pending_status_path)
      expect(page).to have_content(
        AccountRecovery::PendingPresenter.new(recovery_request).time_remaining_until_granted,
      )

      click_button t('account_recovery.pending.status.cancel')

      expect(page).to have_current_path(login_two_factor_options_path)
      expect(page).to have_content(t('account_recovery.pending.cancel_success'))
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(user.reload.phone_configurations).to be_present

      visit user_two_factor_authentication_path
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(account_path)
    end
  end
end
