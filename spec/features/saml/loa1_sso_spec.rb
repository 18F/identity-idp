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
        expect(page.get_rack_session.keys).to include('sp')
      end
    end

    it 'takes user to the service provider, allows user to visit IDP' do
      user = create(:user, :signed_up)
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_continue

      expect(current_url).to eq saml_authn_request

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

      expect(current_url).to match new_user_session_path
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

    it 'after session timeout, signing in takes user back to SP' do
      user = create(:user, :signed_up)
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request
      sp_request_id = ServiceProviderRequest.last.uuid

      visit timeout_path
      expect(current_url).to eq root_url(request_id: sp_request_id)

      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_continue

      expect(current_url).to eq saml_authn_request
    end
  end

  context 'fully signed up user authenticates new sp' do
    let(:user) { create(:user, :signed_up) }
    let(:saml_authn_request) { auth_request.create(saml_settings) }

    before do
      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default
      visit saml_authn_request
    end

    it 'redirects user to verify attributes page' do
      expect(current_url).to eq(sign_up_completed_url)
      expect(page).to have_content(t('titles.sign_up.new_sp'))
    end

    it 'returns to sp after clicking continue' do
      click_continue
      expect(current_url).to eq(saml_authn_request)
    end

    it 'it immediately returns to the SP after signing in again' do
      click_continue

      visit sign_out_url

      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default

      visit saml_authn_request
      expect(current_url).to eq(saml_authn_request)
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

      expect(current_path).to eq two_factor_options_path
    end
  end

  context 'visiting IdP via SP, then using the language selector' do
    it 'preserves the request_id in the url' do
      authn_request = auth_request.create(saml_settings)
      visit authn_request

      within(:css, '.i18n-desktop-dropdown', visible: false) do
        find_link(t('i18n.locale.es'), visible: false).click
      end

      expect(current_url).to match(%r{http://www.example.com/es\?request_id=.+})
    end
  end

  context 'visiting IdP via SP, then going back to SP and visiting IdP again' do
    it 'displays the branded page' do
      authn_request = auth_request.create(saml_settings)
      visit authn_request

      expect(current_url).to match(%r{http://www.example.com/\?request_id=.+})

      visit authn_request

      expect(current_url).to match(%r{http://www.example.com/\?request_id=.+})
    end
  end

  context 'canceling sign in after email and password' do
    it 'returns to the branded landing page' do
      user = create(:user, :signed_up)
      authn_request = auth_request.create(saml_settings)

      visit authn_request
      fill_in_credentials_and_submit(user.email, user.password)
      sp_request_id = ServiceProviderRequest.last.uuid
      sp = ServiceProvider.from_issuer('http://localhost:3000')
      click_link t('links.cancel')

      expect(current_url).to eq new_user_session_url(request_id: sp_request_id)
      expect(page).to have_content t('links.back_to_sp', sp: sp.friendly_name)
    end
  end
end
