require 'rails_helper'

RSpec.feature 'idv gpo step' do
  include IdvStepHelper
  include OidcAuthHelper

  it 'redirects to the review step when the user chooses to verify by letter', :js do
    start_idv_from_sp
    complete_idv_steps_before_gpo_step
    click_on t('idv.buttons.mail.send')

    expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
    expect(page).to have_current_path(idv_review_path)
  end

  it 'allows the user to go back', :js do
    start_idv_from_sp
    complete_idv_steps_before_gpo_step

    click_doc_auth_back_link

    expect(page).to have_current_path(idv_phone_path)
  end

  context 'the user has sent a letter but not verified an OTP' do
    let(:user) { user_with_2fa }
    let(:otp) { 'ABC123' }
    let(:gpo_confirmation_code) do
      create(
        :gpo_confirmation_code,
        profile: User.find(user.id).pending_profile,
        otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
      )
    end

    it 'allows the user to resend a letter and redirects to the come back later step', :js do
      complete_idv_and_return_to_gpo_step

      # Confirm that we show the correct content on
      # the GPO page for users requesting re-send
      expect(page).to have_content(t('idv.titles.mail.resend'))
      expect(page).to have_content(t('idv.messages.gpo.resend_timeframe'))
      expect(page).to have_content(t('idv.messages.gpo.resend_code_warning'))
      expect(page).to have_content(t('idv.buttons.mail.resend'))
      expect(page).to_not have_content(t('idv.messages.gpo.info_alert'))

      expect { click_on t('idv.buttons.mail.resend') }.
        to change { GpoConfirmation.count }.from(1).to(2)
      expect_user_to_be_unverified(user)

      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(page).to have_current_path(idv_come_back_later_path)

      # Confirm that user cannot visit other IdV pages while unverified
      visit idv_agreement_path
      expect(page).to have_current_path(idv_gpo_verify_path)
      visit idv_ssn_url
      expect(page).to have_current_path(idv_gpo_verify_path)
      visit idv_verify_info_url
      expect(page).to have_current_path(idv_gpo_verify_path)

      # complete verification: end to end gpo test
      gpo_confirmation_code
      fill_in t('forms.verify_profile.name'), with: otp
      click_button t('forms.verify_profile.submit')

      expect(user.identity_verified?).to be(true)

      expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
    end

    context 'logged in with PIV/CAC and no password' do
      it 'does not 500' do
        create(:profile, :with_pii, user: user, gpo_verification_pending_at: 1.day.ago)
        create(:piv_cac_configuration, user: user, x509_dn_uuid: 'helloworld', name: 'My PIV Card')
        gpo_confirmation_code

        signin_with_piv(user)
        fill_in t('account.index.password'), with: user.password
        click_button t('forms.buttons.submit.default')

        fill_in t('forms.verify_profile.name'), with: otp
        click_button t('forms.verify_profile.submit')

        expect(user.identity_verified?).to be(true)

        expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
      end
    end

    context 'too much time has passed', :js do
      let(:days_passed) { 31 }
      let(:max_days_before_resend_disabled) { 30 }

      before do
        allow(IdentityConfig.store).to receive(:gpo_max_profile_age_to_send_letter_in_days).
          and_return(max_days_before_resend_disabled)
      end

      it 'does not present the user the option to to resend', :js do
        complete_idv_and_sign_out
        travel_to(days_passed.days.from_now) do
          sign_in_live_with_2fa(user)
          expect(page).to have_current_path(idv_gpo_verify_path)
          expect(page).not_to have_css('.usa-button', text: t('idv.buttons.mail.resend'))
        end
      end

      it 'does not allow the user to go to the resend page manually' do
        complete_idv_and_sign_out
        travel_to(days_passed.days.from_now) do
          sign_in_live_with_2fa(user)
          visit idv_gpo_path
          expect(page).to have_current_path(idv_gpo_verify_path)
          expect(page).not_to have_css('.usa-button', text: t('idv.buttons.mail.resend'))
        end
      end
    end

    it 'allows the user to return to gpo otp confirmation', :js do
      complete_idv_and_return_to_gpo_step
      click_doc_auth_back_link

      expect(page).to have_content(t('forms.verify_profile.title'))
      expect(page).to have_current_path(idv_gpo_verify_path)
      expect_user_to_be_unverified(user)
    end

    def complete_idv_and_sign_out
      start_idv_from_sp
      complete_idv_steps_before_gpo_step(user)
      click_on t('idv.buttons.mail.send')
      fill_in 'Password', with: user_password
      click_continue
      visit root_path
      click_on t('forms.verify_profile.return_to_profile')
      first(:link, t('links.sign_out')).click
    end

    def complete_idv_and_return_to_gpo_step
      complete_idv_and_sign_out
      sign_in_live_with_2fa(user)
      click_on t('idv.messages.gpo.resend')
    end

    def expect_user_to_be_unverified(user)
      expect(user.events.account_verified.size).to be(0)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq false
      expect(profile.gpo_verification_pending?).to eq true
    end
  end

  context 'GPO verified user has reset their password and needs to re-verify with GPO again', :js do
    let(:user) { user_verified_with_gpo }

    it 'shows the user a GPO index screen asking to send a letter' do
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

      expect(page).to have_content(t('forms.verify_profile.instructions'))
    end
  end
end
