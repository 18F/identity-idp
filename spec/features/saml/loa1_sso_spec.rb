require 'rails_helper'

feature 'LOA1 Single Sign On' do
  include SamlAuthHelper

  context 'First time registration' do
    it 'takes user to agency handoff page when sign up flow complete' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      @saml_authn_request = auth_request.create(saml_settings)

      user = create(:user, :with_phone)
      sign_in_and_require_viewing_recovery_code(user)

      click_acknowledge_recovery_code
      expect(current_path).to eq sign_up_completed_path
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
  end

  def sign_in_and_require_viewing_recovery_code(user)
    login_as(user, scope: :user, run_callbacks: false)
    Warden.on_next_request do |proxy|
      session = proxy.env['rack.session']
      session['warden.user.user.session'] = {
        'need_two_factor_authentication' => true,
        first_time_recovery_code_view: true,
      }
      session[:saml_request_url] = @saml_authn_request
      session[:sp] = { loa3: false, name: 'Your friendly Government Agency' }
    end
    visit profile_path
    click_submit_default
  end
end
