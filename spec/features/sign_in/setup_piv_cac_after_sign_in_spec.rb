require 'rails_helper'

RSpec.describe 'Setup PIV/CAC after sign-in' do
  include SamlAuthHelper

  scenario 'user opts to not add piv/cac card' do
    perform_steps_to_get_to_add_piv_cac_during_sign_up

    click_on t('forms.piv_cac_setup.no_thanks')

    expect(page).to have_current_path(sign_up_completed_path)
  end

  context 'without an associated service provider' do
    scenario 'user opts to not add piv/cac card' do
      perform_steps_to_get_to_add_piv_cac_during_sign_up(sp: nil)

      click_on t('forms.piv_cac_setup.no_thanks')

      expect(page).to have_current_path(account_path)
    end
  end

  scenario 'user opts to add piv/cac card' do
    perform_steps_to_get_to_add_piv_cac_during_sign_up

    fill_in t('forms.piv_cac_setup.nickname'), with: 'Card 1'
    click_on t('forms.piv_cac_setup.submit')
    follow_piv_cac_redirect

    expect(page).to have_current_path(sign_up_completed_path)
  end

  scenario 'user opts to add piv/cac card but gets an error' do
    perform_steps_to_get_to_add_piv_cac_during_sign_up

    fill_in t('forms.piv_cac_setup.nickname'), with: 'Card 1'
    stub_piv_cac_service(error: 'certificate.bad')
    click_on t('forms.piv_cac_setup.submit')
    follow_piv_cac_redirect

    expect(page).to have_current_path(setup_piv_cac_error_path(error: 'certificate.bad'))
  end

  scenario 'user opts to add piv/cac card and has piv cac redirect in CSP' do
    allow(Identity::Hostdata).to receive(:env).and_return('test')
    allow(Identity::Hostdata).to receive(:domain).and_return('example.com')

    perform_steps_to_get_to_add_piv_cac_during_sign_up

    expected_form_action = <<-STR.squish
      form-action https://*.pivcac.test.example.com 'self'
      http://localhost:7654 https://example.com
    STR

    expect(page.response_headers['Content-Security-Policy']).
      to(include(expected_form_action))
  end

  def perform_steps_to_get_to_add_piv_cac_during_sign_up(sp: :oidc)
    user = create(:user, :fully_registered, :with_phone)
    if sp
      visit_idp_from_sp_with_ial1(sp)
    else
      visit new_user_session_path
    end

    click_on t('account.login.piv_cac')
    stub_piv_cac_service
    click_on t('forms.piv_cac_login.submit')

    follow_piv_cac_redirect
    expect(page).to have_current_path(login_piv_cac_error_path(error: 'user.not_found'))
    click_on t('instructions.mfa.piv_cac.back_to_sign_in')

    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    expect(current_path).to eq login_add_piv_cac_prompt_path
    fill_in t('forms.piv_cac_setup.nickname'), with: 'Card 1'
  end
end
