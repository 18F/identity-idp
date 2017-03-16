require 'rails_helper'

feature 'LOA1 Single Sign On' do
  include SamlAuthHelper

  context 'First time registration' do
    it 'takes user to agency handoff page when sign up flow complete' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      saml_authn_request = auth_request.create(saml_settings)
      user = create(:user, :with_phone)

      visit saml_authn_request
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

    it 'shows user the start page without accordion' do
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request

      expect(current_url).to match sign_up_start_path
      expect(page).to have_content(
        t('devise.registrations.start.introduction.loa3_requested.false')
      )
      expect(page).to_not have_css('.accordion-header')
    end

    it 'allows user to view recovery code via profile', :js do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      user = create(:user, :with_phone)

      loa1_sp_session
      sign_in_and_require_viewing_recovery_code(user)
      code = generate_personal_key(user)
      expect(current_path).to eq sign_up_recovery_code_path

      click_on(t('shared.nav_auth.my_account'))
      click_on(t('profile.links.regenerate_recovery_code'))
      click_on(t('forms.buttons.continue'))
      enter_personal_key_words_on_modal(code)
      click_on t('forms.buttons.continue'), class: 'recovery-code-confirm'

      expect(current_path).to eq sign_up_completed_path
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

  def generate_personal_key(user)
    code = RecoveryCodeGenerator.new(user).create
    generator = instance_double(RecoveryCodeGenerator)
    allow(RecoveryCodeGenerator).to receive(:new).with(user).and_return(generator)
    allow(generator).to receive(:create).and_return(code)
    code
  end

  def enter_personal_key_words_on_modal(code)
    code_words = code.split(' ')
    code_words.each_with_index do |word, index|
      fill_in "recovery-#{index}", with: word
    end
  end
end
