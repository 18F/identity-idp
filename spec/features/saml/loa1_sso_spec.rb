require 'rails_helper'

feature 'LOA1 Single Sign On' do
  include SamlAuthHelper

  context 'First time registration' do
    it 'takes user to agency handoff page when sign up flow complete' do
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request
      sign_up_and_2fa_loa1_user

      expect(current_path).to eq sign_up_completed_path

      click_on t('forms.buttons.continue_to', sp: 'Your friendly Government Agency')

      expect(current_url).to eq saml_authn_request
    end

    it 'takes user to the service provider, allows user to visit IDP' do
      user = create(:user, :signed_up)
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request
      sign_in_live_with_2fa(user)

      expect(current_url).to eq saml_authn_request

      visit root_path
      expect(current_path).to eq profile_path
    end

    it 'shows user the start page without accordion' do
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request

      expect(current_url).to match sign_up_start_path
      expect(page).to have_content(
        t('devise.registrations.start.introduction.loa3_requested.false')
      )
      expect(page).to_not have_css('.accordion-header')
    end
  end

  def sign_in_and_require_viewing_recovery_code(user)
    login_as(user, scope: :user, run_callbacks: false)
    Warden.on_next_request do |proxy|
      session = proxy.env['rack.session']
      session['warden.user.user.session'] = {
        'need_two_factor_authentication' => true,
        first_time_recovery_code_view: true,
      }
    end

    visit profile_path
    click_submit_default
  end
end
