require 'rails_helper'

RSpec.feature 'idv request letter step', allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include OidcAuthHelper

  let(:minimum_wait_for_letter) { 24 }
  let(:days_passed) { max_days_before_resend_disabled + 1 }
  let(:max_days_before_resend_disabled) { 30 }

  before do
    allow(IdentityConfig.store).to receive(:minimum_wait_before_another_usps_letter_in_hours).
      and_return(minimum_wait_for_letter)
    allow(IdentityConfig.store).to receive(:gpo_max_profile_age_to_send_letter_in_days).
      and_return(max_days_before_resend_disabled)
    allow(IdentityConfig.store).to receive(:second_mfa_reminder_account_age_in_days).
      and_return(days_passed + 1)
  end

  it 'visits and completes the enter password step when the user chooses verify by letter', :js do
    start_idv_from_sp
    complete_idv_steps_before_gpo_step
    click_on t('idv.buttons.mail.send')

    expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
    expect(page).to have_current_path(idv_enter_password_path)

    complete_enter_password_step
    expect(page).to have_content(t('idv.messages.gpo.letter_on_the_way'))
  end

  context 'the user has sent a letter but not verified an OTP' do
    let(:user) { user_with_2fa }

    before do
      # Without this, the check for GPO expiration leaves an expired
      # OTP rate limiter laying around.
      allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(3)
    end

    it 'if not rate limited, allow user to resend letter & redirect to letter enqueued step', :js do
      complete_idv_by_mail_and_sign_out

      # rate-limited because too little time has passed
      sign_in_live_with_2fa(user)
      confirm_rate_limited
      sign_out

      # still rate-limited because too little time has passed
      travel_to((minimum_wait_for_letter - 1).hours.from_now) do
        sign_in_live_with_2fa(user)
        confirm_rate_limited
        sign_out
      end

      # will be rate-limted after expiration
      travel_to(days_passed.days.from_now) do
        sign_in_live_with_2fa(user)
        confirm_rate_limited
        sign_out
        # Clear MFA SMS message from the future to allow re-logging in with test helper
        Telephony::Test::Message.clear_messages
      end

      # can re-request after the waiting period
      travel_to((minimum_wait_for_letter + 1).hours.from_now) do
        sign_in_live_with_2fa(user)
        click_on t('idv.messages.gpo.resend')

        # Confirm that we show the correct content on
        # the GPO page for users requesting re-send
        expect(page).to have_content(t('idv.gpo.request_another_letter.title'))
        expect(page).to have_content(
          strip_tags(t('idv.gpo.request_another_letter.instructions_html')),
        )
        expect(page).to have_content(t('idv.gpo.request_another_letter.button'))
        expect(page).to_not have_content(t('idv.messages.gpo.info_alert'))

        # Ensure user can go back from this page
        click_doc_auth_back_link
        expect(page).to have_content(t('idv.gpo.title'))
        expect(page).to have_current_path(idv_verify_by_mail_enter_code_path)
        expect_user_to_be_unverified(user)
        click_on t('idv.messages.gpo.resend')

        # And then actually ask for a resend
        expect { click_on t('idv.gpo.request_another_letter.button') }.
          to change { GpoConfirmation.count }.from(1).to(2)
        expect_user_to_be_unverified(user)
        expect(page).to have_content(t('idv.messages.gpo.another_letter_on_the_way'))
        expect(page).to have_content(t('idv.titles.come_back_later'))
        expect(page).to have_current_path(idv_letter_enqueued_path)

        # Confirm that user cannot visit other IdV pages while unverified
        visit idv_agreement_path
        expect(page).to have_current_path(idv_letter_enqueued_path)
        visit idv_ssn_url
        expect(page).to have_current_path(idv_letter_enqueued_path)
        visit idv_verify_info_url
        expect(page).to have_current_path(idv_letter_enqueued_path)

        # complete verification: end to end gpo test
        sign_out
        sign_in_live_with_2fa(user)

        complete_gpo_verification(user)
        expect(user.identity_verified?).to be(true)
        expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
      end
    end

    context 'logged in with PIV/CAC and no password' do
      it 'does not 500' do
        create(:profile, :with_pii, user: user, gpo_verification_pending_at: 1.day.ago)
        create(:gpo_confirmation_code, profile: user.pending_profile)
        create(:piv_cac_configuration, user: user, x509_dn_uuid: 'helloworld', name: 'My PIV Card')

        signin_with_piv(user)
        fill_in t('account.index.password'), with: user.password
        click_button t('forms.buttons.submit.default')

        complete_gpo_verification(user)

        expect(user.identity_verified?).to be(true)

        expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
      end
    end

    def complete_idv_by_mail_and_sign_out
      start_idv_from_sp
      complete_idv_steps_before_gpo_step(user)
      click_on t('idv.buttons.mail.send')
      fill_in 'Password', with: user_password
      click_continue
      sign_out
    end

    def expect_user_to_be_unverified(user)
      expect(user.events.account_verified.size).to be(0)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq false
      expect(profile.gpo_verification_pending?).to eq true
    end

    def sign_out
      visit sign_out_url
    end

    def confirm_rate_limited
      expect(page).to have_current_path(idv_verify_by_mail_enter_code_path)
      expect(page).not_to have_link(
        t('idv.gpo.did_not_receive_letter.intro.request_new_letter_link'),
      )
      # does not allow the user to go to the resend page manually
      visit idv_request_letter_path

      expect(page).to have_current_path(idv_verify_by_mail_enter_code_path)
      expect(page).not_to have_link(
        t('idv.gpo.did_not_receive_letter.intro.request_new_letter_link'),
      )
    end
  end

  context 'GPO verified user has reset their password and needs to re-verify with GPO again', :js do
    let(:user) { user_verified_with_gpo }

    it 'shows the user the request letter page' do
      visit_idp_from_ial2_oidc_sp
      trigger_reset_password_and_click_email_link(user.email)
      reset_password_and_sign_back_in(user)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_on(t('links.account.reactivate.without_key'))
      click_continue
      complete_all_doc_auth_steps
      enter_gpo_flow
      expect(page).to have_content(t('idv.titles.mail.verify'))
    end
  end

  context 'Verified resets password, requests GPO, then signs in using SP', :js do
    let(:user) { user_verified }
    let(:new_password) { 'a really long password' }

    it 'shows the user the GPO code entry screen' do
      visit_idp_from_ial2_oidc_sp
      trigger_reset_password_and_click_email_link(user.email)
      reset_password_and_sign_back_in(user, new_password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_on(t('links.account.reactivate.without_key'))
      click_continue
      complete_all_doc_auth_steps
      enter_gpo_flow
      click_on(t('idv.buttons.mail.send'))
      fill_in 'Password', with: new_password
      click_continue
      set_new_browser_session
      visit_idp_from_ial2_oidc_sp
      signin(user.email, new_password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_content(t('idv.gpo.intro'))
    end
  end
end
