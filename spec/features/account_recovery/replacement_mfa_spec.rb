require 'rails_helper'

RSpec.describe 'Account Recovery: replace inaccessible MFA', email: true do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(1)
  end

  it 'recovers the account, verifies a new authenticator, and signs in with it afterward' do
    signin(user.email, user.password)
    click_link t('two_factor_authentication.login_options_link_text')
    click_link t('two_factor_authentication.account_recovery.recover_link')
    click_button t('account_recovery.start.continue')

    secret = nil
    travel_to(Time.zone.now + 2.days) do
      GrantAccountRecoveryRequestsAndSendEmailsJob.new.perform(Time.zone.now)
      open_last_email
      click_email_link_matching(%r{account_recovery/verify\?.*token})
      fill_in t('account.index.password'), with: user.password
      click_button t('account_recovery.verify.continue')

      expect(page).to have_current_path(account_recovery_new_mfa_setup_path)
      expect(page).to have_content(t('account_recovery.new_mfa_setup.alert'))
      expect(user.reload.phone_configurations.first).to be_suspended_for_account_recovery
      check 'recovery_mfa_auth_app'
      check 'recovery_mfa_backup_code'
      click_button t('forms.buttons.continue')

      secret = find('#qr-code').text.strip
      fill_in 'name', with: 'Replacement authenticator'
      fill_in 'code', with: 'invalid'
      click_submit_default
      expect(user.reload.phone_configurations).not_to be_empty

      code = ROTP::TOTP.new(secret, interval: IdentityConfig.store.totp_code_interval).now
      fill_in 'name', with: 'Replacement authenticator'
      fill_in 'code', with: code
      click_submit_default

      # Recovery completes on the first verified replacement; the second
      # selection continues as a normal, authenticated enrollment.
      expect(user.reload.phone_configurations).to be_empty
      expect(user.account_recovery_requests.last.state).to eq(AccountRecoveryRequest::COMPLETED)
      expect(page).to have_current_path(backup_code_setup_path)

      click_continue

      expect(page).to have_current_path(account_path)
      t('account_recovery.new_mfa_setup.completed_html').split('<br>').each do |part|
        expect(page).to have_content(strip_tags(part))
      end
      expect(user.reload.backup_code_configurations).not_to be_empty
    end

    Capybara.reset_sessions!
    travel_to(Time.zone.now + 2.days + 1.minute) do
      signin(user.email, user.password)
      code = ROTP::TOTP.new(secret, interval: IdentityConfig.store.totp_code_interval).now
      fill_in 'code', with: code
      click_button t('forms.buttons.submit.default')

      expect(page).to have_current_path(account_path)
    end
  end
end
