require 'rails_helper'

RSpec.feature 'idv request letter step' do
  include IdvStepHelper
  include OidcAuthHelper

  it 'visits and completes the enter password step when the user chooses verify by letter', :js do
    start_idv_from_sp
    complete_idv_steps_before_gpo_step
    click_on t('idv.buttons.mail.send')

    expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
    expect(page).to have_current_path(idv_enter_password_path)

    complete_enter_password_step
    expect(page).to have_content(t('idv.messages.gpo.letter_on_the_way'))
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
