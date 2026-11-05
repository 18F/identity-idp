require 'rails_helper'

RSpec.describe 'Account Recovery: redeem the recovery link', email: true do
  let(:user) { create(:user, :fully_registered) }
  let(:user_email) { user.email_addresses.first.email }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(1)
  end

  def request_account_recovery
    signin(user_email, user.password)
    click_link t('two_factor_authentication.login_options_link_text')
    click_link t('two_factor_authentication.account_recovery.recover_link')

    expect(page).to have_content t('account_recovery.start.header')

    click_button t('account_recovery.start.continue')

    # The confirmation page signs the user out; they return by signing in again.
    expect(page).to have_current_path(account_recovery_confirm_request_path)
    expect(page).to have_content t('account_recovery.confirm_request.header')
  end

  it 'walks the user from request through password confirmation' do
    request_account_recovery
    reset_email

    travel_to(Time.zone.now + 2.days) do
      GrantAccountRecoveryRequestsAndSendEmailsJob.new.perform(Time.zone.now)

      open_last_email
      click_email_link_matching(%r{account_recovery/verify\?.*token})

      # The link is sessionless, so the user confirms their password to sign in.
      expect(page).to have_content t('account_recovery.verify.header')
      expect(page).to have_current_path(account_recovery_verify_path)
      expect(page).not_to have_css('input[name="token"]', visible: false)

      fill_in t('account.index.password'), with: user.password
      click_button t('account_recovery.verify.continue')

      # Password confirmation gives the user a temporary pre-2FA session that
      # continues to replacement MFA setup.
      expect(page).to have_current_path(account_recovery_new_mfa_setup_path)
      expect(page).to have_content t('account_recovery.new_mfa_setup.header')
      expect(page).to have_content t('account_recovery.new_mfa_setup.intro')
    end

    recovery_request = AccountRecoveryRequest.active_for_user(user)
    expect(recovery_request.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
    expect(recovery_request.password_verified_at).to be_present
  end

  it 'does not grant a fully authenticated session' do
    request_account_recovery
    reset_email

    travel_to(Time.zone.now + 2.days) do
      GrantAccountRecoveryRequestsAndSendEmailsJob.new.perform(Time.zone.now)

      open_last_email
      click_email_link_matching(%r{account_recovery/verify\?.*token})

      fill_in t('account.index.password'), with: user.password
      click_button t('account_recovery.verify.continue')

      visit account_path

      expect(page).to_not have_current_path(account_path)
    end
  end

  it 'rejects an incorrect password' do
    request_account_recovery
    reset_email

    travel_to(Time.zone.now + 2.days) do
      GrantAccountRecoveryRequestsAndSendEmailsJob.new.perform(Time.zone.now)

      open_last_email
      click_email_link_matching(%r{account_recovery/verify\?.*token})

      fill_in t('account.index.password'), with: 'not the right password'
      click_button t('account_recovery.verify.continue')

      expect(page).to have_content t('errors.confirm_password_incorrect')
      expect(page).to have_content t('account_recovery.verify.header')
    end
  end

  it 'signs the user out after the request and offers existing MFA on the next sign-in' do
    request_account_recovery

    expect(page).not_to have_css('form[action*="cancel"], a[href*="cancel"]')

    visit account_path

    expect(page).to have_current_path(root_path)

    signin(user_email, user.password)

    expect(page).to have_content t('account_recovery.pending.mfa_banner')
    expect(page).not_to have_link(href: account_recovery_start_path)

    visit account_recovery_start_path

    expect(page).to have_current_path(login_two_factor_options_path)
    expect(AccountRecoveryRequest.active_for_user(user).state)
      .to eq(AccountRecoveryRequest::WAITING)
  end

  it 'routes a returning user back into recovery after the link is redeemed' do
    request_account_recovery
    reset_email

    travel_to(Time.zone.now + 2.days) do
      GrantAccountRecoveryRequestsAndSendEmailsJob.new.perform(Time.zone.now)

      open_last_email
      click_email_link_matching(%r{account_recovery/verify\?.*token})

      fill_in t('account.index.password'), with: user.password
      click_button t('account_recovery.verify.continue')

      visit root_path

      expect(page).to have_current_path(account_recovery_new_mfa_setup_path)

      Capybara.reset_sessions!
      signin(user_email, user.password)

      expect(page).to have_current_path(account_recovery_new_mfa_setup_path)
    end
  end

  it 'expires an unredeemed link and allows a new request' do
    request_account_recovery

    travel_to(Time.zone.now + 2.days) do
      GrantAccountRecoveryRequestsAndSendEmailsJob.new.perform(Time.zone.now)
    end

    travel_to(Time.zone.now + 5.days) do
      signin(user_email, user.password)

      expect(AccountRecoveryRequest.active_for_user(user)).to be_nil
    end
  end

  context 'in a browser', js: true do
    around do |example|
      original_protection = ActionController::Base.allow_forgery_protection
      original_origin_check = ActionController::Base.forgery_protection_origin_check
      ActionController::Base.allow_forgery_protection = true
      ActionController::Base.forgery_protection_origin_check = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original_protection
      ActionController::Base.forgery_protection_origin_check = original_origin_check
    end

    it 'submits and retries the clean password form with CSRF protection' do
      token = SecureRandom.uuid
      recovery_request = create(
        :account_recovery_request,
        :granted,
        user: user,
        token_fingerprint: AccountRecovery::TokenCreator.fingerprint(token),
      )

      visit account_recovery_verify_path(token: token)

      expect(page).to have_current_path(account_recovery_verify_path)
      expect(page).not_to have_css('input[name="token"]', visible: false)

      fill_in t('account.index.password'), with: 'wrong password'
      click_button t('account_recovery.verify.continue')

      expect(page).to have_content(t('errors.confirm_password_incorrect'))
      expect(page).to have_current_path(account_recovery_verify_path)

      fill_in t('account.index.password'), with: user.password
      click_button t('account_recovery.verify.continue')

      expect(page).to have_content(t('account_recovery.new_mfa_setup.header'))
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)

      visit account_path

      expect(page).not_to have_current_path(account_path)
    end
  end
end
