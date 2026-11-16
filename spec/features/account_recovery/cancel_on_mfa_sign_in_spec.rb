require 'rails_helper'

RSpec.feature 'Account recovery request cancelled by signing in with existing MFA' do
  it 'confirms the request, signs out, and cancels only after signing in with existing MFA' do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    user = create(:user, :fully_registered)

    sign_in_user(user)
    visit account_recovery_start_path
    click_button t('account_recovery.start.continue')

    expect(page).to have_current_path(account_recovery_confirm_request_path)
    expect(page).to have_content(t('account_recovery.confirm_request.header'))
    expect(page).to have_content(user.last_sign_in_email_address.email)
    expect(page).not_to have_css('form[action*="cancel"], a[href*="cancel"]')
    recovery_request = AccountRecoveryRequest.active_for_user(user)

    visit account_path
    expect(page).to have_current_path(root_path)
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

    sign_in_user(user)

    expect(page).to have_content(t('account_recovery.pending.mfa_banner'))
    expect(recovery_request.reload).to be_active
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_current_path(account_path)
    expect(page).to have_content(t('account_recovery.pending.cancel_success'))
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
    expect(recovery_request.cancel_reason).to eq(AccountRecoveryRequest::CANCEL_REASON_MFA_USED)
    expect(page).not_to have_content(t('account_recovery.pending.mfa_banner'))
    expect_delivered_email(
      to: [user.last_sign_in_email_address.email],
      subject: t('user_mailer.account_recovery_cancelled.subject', app_name: APP_NAME),
    )
  end

  it 'keeps the recovery banner on the first MFA page and when choosing another method' do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    user = create(:user, :fully_registered)
    recovery_request = create(:account_recovery_request, :waiting, user: user)

    sign_in_user(user)
    expect(page).to have_content(t('account_recovery.pending.mfa_banner'))

    click_link t('two_factor_authentication.login_options_link_text')
    expect(page).to have_content(t('account_recovery.pending.mfa_banner'))
    expect(page).not_to have_link(href: account_recovery_start_path)
    expect(page).not_to have_link(t('two_factor_authentication.account_reset.link'))
    expect(recovery_request.reload).to be_active
  end

  it 'does not cancel or email on an invalid MFA attempt' do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    user = create(:user, :fully_registered)
    recovery_request = create(:account_recovery_request, :waiting, user: user)

    sign_in_user(user)
    emails_sent = ActionMailer::Base.deliveries.size
    fill_in 'code', with: '000000'
    click_submit_default

    expect(page).to have_content(t('account_recovery.pending.mfa_banner'))
    expect(recovery_request.reload).to be_active
    expect(ActionMailer::Base.deliveries.size).to eq(emails_sent)
  end

  it 'cancels recovery when signing in from a service provider' do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    user = create(:user, :fully_registered)
    recovery_request = create(:account_recovery_request, :waiting, user: user)
    sp = create(:service_provider, issuer: 'https://example.test/sp')
    page.set_rack_session(
      sp: {
        issuer: sp.issuer,
        request_url: 'https://example.test/auth',
        acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      },
    )
    signin(user.email, user.password)
    expect(page).to have_content(t('account_recovery.pending.mfa_banner'))
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
    expect_delivered_email(
      to: [user.last_sign_in_email_address.email],
      subject: t('user_mailer.account_recovery_cancelled.subject', app_name: APP_NAME),
    )
  end
end
