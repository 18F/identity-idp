require 'rails_helper'

feature 'idv gpo step', :js do
  include IdvStepHelper
  include OidcAuthHelper

  it 'redirects to the review step when the user chooses to verify by letter' do
    start_idv_from_sp
    complete_idv_steps_before_gpo_step
    click_on t('idv.buttons.mail.send')

    expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
    expect(page).to have_current_path(idv_review_path)
  end

  it 'allows the user to go back' do
    start_idv_from_sp
    complete_idv_steps_before_gpo_step

    click_doc_auth_back_link

    expect(page).to have_current_path(idv_phone_path)
  end

  context 'the user has sent a letter but not verified an OTP' do
    let(:user) { user_with_2fa }

    it 'allows the user to resend a letter and redirects to the come back later step' do
      complete_idv_and_return_to_gpo_step

      expect { click_on t('idv.buttons.mail.resend') }.
        to change { GpoConfirmation.count }.from(1).to(2)
      expect_user_to_be_unverified(user)
      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(page).to have_current_path(idv_come_back_later_path)
    end

    it 'allows the user to return to gpo otp confirmation' do
      complete_idv_and_return_to_gpo_step
      click_doc_auth_back_link

      expect(page).to have_content(t('forms.verify_profile.title'))
      expect(page).to have_current_path(idv_gpo_verify_path)
      expect_user_to_be_unverified(user)
    end

    def complete_idv_and_return_to_gpo_step
      start_idv_from_sp
      complete_idv_steps_before_gpo_step(user)
      click_on t('idv.buttons.mail.send')
      fill_in 'Password', with: user_password
      click_continue
      acknowledge_and_confirm_personal_key
      visit root_path
      click_on t('idv.buttons.cancel')
      first(:link, t('links.sign_out')).click
      sign_in_live_with_2fa(user)
      click_on t('idv.messages.gpo.resend')
    end

    def expect_user_to_be_unverified(user)
      expect(user.events.account_verified.size).to be(0)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq false
      expect(profile.deactivation_reason).to eq 'gpo_verification_pending'
    end
  end

  context 'GPO verified user has reset their password and needs to re-verify with GPO again' do
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

  context 'Verified user resets password, begins doc auth and requests GPO, then signs in using SP' do
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
      page.find(
        'label',
        text: t('forms.personal_key.required_checkbox'),
        wait: 5,
      ).click
      click_continue
      set_new_browser_session
      visit_idp_from_ial2_oidc_sp
      signin(user.email, new_password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      binding.pry
      expect(page).to have_content(t('forms.verify_profile.welcome_back_description'))
    end
  end
end
