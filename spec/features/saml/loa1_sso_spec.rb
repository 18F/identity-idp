require 'rails_helper'

feature 'LOA1 Single Sign On' do
  include SamlAuthHelper

  context 'First time registration', email: true do
    it 'takes user to agency handoff page when sign up flow complete' do
      email = 'test@test.com'
      authn_request = auth_request.create(saml_settings)

      perform_in_browser(:one) do
        visit authn_request
        sign_up_user_from_sp_without_confirming_email(email)
      end

      perform_in_browser(:two) do
        confirm_email_in_a_different_browser(email)

        expect(current_path).to eq sign_up_completed_path
        within('.requested-attributes') do
          expect(page).to have_content t('help_text.requested_attributes.email')
          expect(page).to_not have_content t('help_text.requested_attributes.address')
          expect(page).to_not have_content t('help_text.requested_attributes.birthdate')
          expect(page).to_not have_content t('help_text.requested_attributes.name')
          expect(page).to_not have_content t('help_text.requested_attributes.phone')
          expect(page).
            to_not have_content t('help_text.requested_attributes.social_security_number')
        end

        click_on t('forms.buttons.continue')

        expect(current_url).to eq authn_request
        expect(page.get_rack_session.keys).to_not include('sp')
      end
    end

    it 'takes user to the service provider, allows user to visit IDP' do
      user = create(:user, :signed_up)
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request
      sign_in_live_with_2fa(user)

      expect(current_url).to eq saml_authn_request
      expect(page.get_rack_session.keys).to_not include('sp')

      visit root_path
      expect(current_path).to eq account_path
    end

    it 'shows user the start page without accordion' do
      saml_authn_request = auth_request.create(saml_settings)
      sp_content = [
        'Your friendly Government Agency',
        t('headings.create_account_with_sp.sp_text'),
      ].join(' ')

      visit saml_authn_request

      expect(current_url).to match sign_up_start_path
      expect(page).to have_content(sp_content)
      expect(page).to_not have_css('.accordion-header')
    end

    it 'shows user the start page with a link back to the SP' do
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request

      cancel_callback_url = 'http://localhost:3000'

      expect(page).to have_link(
        t('links.back_to_sp', sp: 'Your friendly Government Agency'), href: cancel_callback_url
      )
    end

    it 'user can view and confirm personal key during sign up', :js do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      user = create(:user, :with_phone)
      code = '1234'
      stub_personal_key(user: user, code: code)

      loa1_sp_session
      sign_in_and_require_viewing_personal_key(user)
      expect(current_path).to eq sign_up_personal_key_path

      click_on(t('forms.buttons.continue'))
      enter_personal_key_words_on_modal(code)
      click_on t('forms.buttons.continue'), class: 'personal-key-confirm'

      expect(current_path).to eq sign_up_completed_path
    end

    it 'after session timeout, signing in takes user back to SP' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)

      user = create(:user, :signed_up)
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request
      sp_request_id = ServiceProviderRequest.last.uuid
      page.set_rack_session(sp: {})
      visit new_user_session_url(request_id: sp_request_id)
      fill_in_credentials_and_submit(user.email, user.password)
      click_submit_default

      expect(current_url).to eq saml_authn_request
    end
  end

  context 'fully signed up user is signed in with email and password only' do
    it 'prompts to enter OTP' do
      user = create(:user, :signed_up)
      sign_in_user(user)

      saml_authn_request = auth_request.create(saml_settings)
      visit saml_authn_request

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
    end
  end

  context 'user that has not yet set up 2FA is signed in with email and password only' do
    it 'prompts to set up 2FA' do
      sign_in_user

      saml_authn_request = auth_request.create(saml_settings)
      visit saml_authn_request

      expect(current_path).to eq phone_setup_path
    end
  end

  context 'visiting IdP via SP, then going back to SP and visiting IdP again' do
    it 'displays the branded page' do
      authn_request = auth_request.create(saml_settings)
      visit authn_request

      expect(current_url).to match(%r{http://www.example.com/sign_up/start\?request_id=.+})

      visit authn_request

      expect(current_url).to match(%r{http://www.example.com/sign_up/start\?request_id=.+})
    end
  end

  context 'canceling sign in after email and password' do
    it 'returns to the branded landing page' do
      user = create(:user, :signed_up)
      authn_request = auth_request.create(saml_settings)

      visit authn_request
      click_link t('links.sign_in')
      fill_in_credentials_and_submit(user.email, user.password)
      sp_request_id = ServiceProviderRequest.last.uuid
      sp = ServiceProvider.from_issuer('http://localhost:3000')
      click_link t('links.cancel')

      expect(current_url).to eq sign_up_start_url(request_id: sp_request_id)
      expect(page).to have_content t('links.back_to_sp', sp: sp.friendly_name)
    end
  end

  context 'creating two accounts during the same session' do
    it 'allows the second account creation process to complete fully', email: true do
      first_email = 'test1@test.com'
      second_email = 'test2@test.com'
      authn_request = auth_request.create(saml_settings)

      perform_in_browser(:one) do
        visit authn_request
        sign_up_user_from_sp_without_confirming_email(first_email)
      end

      perform_in_browser(:two) do
        confirm_email_in_a_different_browser(first_email)
        click_button t('forms.buttons.continue')

        expect(current_url).to eq authn_request
        expect(page.get_rack_session.keys).to_not include('sp')
      end

      perform_in_browser(:one) do
        visit authn_request
        sign_up_user_from_sp_without_confirming_email(second_email)
      end

      perform_in_browser(:two) do
        confirm_email_in_a_different_browser(second_email)
        click_button t('forms.buttons.continue')

        expect(current_url).to eq authn_request
        expect(page.get_rack_session.keys).to_not include('sp')
      end
    end
  end

  def sign_in_and_require_viewing_personal_key(user)
    login_as(user, scope: :user, run_callbacks: false)
    Warden.on_next_request do |proxy|
      session = proxy.env['rack.session']
      session['warden.user.user.session'] = {
        'need_two_factor_authentication' => true,
        first_time_personal_key_view: true,
      }
    end

    visit account_path
    click_submit_default
  end

  def stub_personal_key(user:, code:)
    generator = instance_double(PersonalKeyGenerator)
    allow(PersonalKeyGenerator).to receive(:new).with(user).and_return(generator)
    allow(generator).to receive(:create).and_return(code)
    code
  end

  def enter_personal_key_words_on_modal(code)
    fill_in 'personal_key', with: code
  end
end
