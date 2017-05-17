require 'rails_helper'

feature 'LOA3 Single Sign On' do
  include SamlAuthHelper
  include IdvHelper

  context 'First time registration' do
    it 'redirects to original SAML Authn Request after IdV is complete', email: true do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
      email = 'test@test.com'

      visit saml_authn_request
      click_link t('sign_up.registrations.create_account')
      submit_form_with_valid_email
      click_confirmation_link_in_email(email)
      submit_form_with_valid_password
      set_up_2fa_with_valid_phone
      enter_2fa_code

      expect(current_path).to eq verify_path
      click_on 'Yes'
      user = User.find_with_email(email)
      complete_idv_profile_ok(user.reload)
      click_acknowledge_personal_key

      expect(page).to have_content t(
        'titles.sign_up.completion_html',
        accent: t('titles.sign_up.loa3'),
        app: APP_NAME
      )
      within('.requested-attributes') do
        expect(page).to have_content t('help_text.requested_attributes.email')
        expect(page).to_not have_content t('help_text.requested_attributes.address')
        expect(page).to_not have_content t('help_text.requested_attributes.birthdate')
        expect(page).to have_content t('help_text.requested_attributes.given_name')
        expect(page).to have_content t('help_text.requested_attributes.family_name')
        expect(page).to have_content t('help_text.requested_attributes.phone')
        expect(page).to have_content t('help_text.requested_attributes.social_security_number')
      end

      click_on I18n.t('forms.buttons.continue')
      expect(current_url).to eq saml_authn_request

      user_access_key = user.unlock_user_access_key(Features::SessionHelper::VALID_PASSWORD)
      profile_phone = user.active_profile.decrypt_pii(user_access_key).phone

      expect(xmldoc.phone_number.children.children.to_s).to eq(profile_phone)
    end

    it 'shows user the start page with accordion' do
      saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
      sp_content = [
        'Test SP',
        t('headings.create_account_with_sp.sp_text'),
      ].join(' ')

      visit saml_authn_request

      expect(current_path).to match sign_up_start_path
      expect(page).to have_content(sp_content)
      expect(page).to have_css('.accordion-header-controls',
                               text: t('devise.registrations.start.accordion'))
    end
  end

  context 'canceling verification' do
    context 'with js', js: true do
      it 'returns user to personal key page if they sign up via loa3' do
        user = create(:user, phone: '1 (111) 111-1111', personal_key: nil)
        sign_in_with_warden(user)
        loa3_sp_session

        visit verify_path
        click_on t('links.cancel')
        click_on t('idv.buttons.cancel')

        expect(current_path).to eq(manage_personal_key_path)
      end

      it 'returns user to profile page if they have previously signed up' do
        sign_in_and_2fa_user
        loa3_sp_session

        visit verify_path
        click_on t('links.cancel')
        click_on t('idv.buttons.cancel')

        expect(current_path).to match(account_path)
      end
    end

    context 'without js' do
      it 'returns user to personal key page if they sign up via loa3' do
        user = create(:user, phone: '1 (111) 111-1111', personal_key: nil)
        sign_in_with_warden(user)
        loa3_sp_session

        visit verify_path
        click_idv_cancel

        expect(current_path).to eq(manage_personal_key_path)
      end

      it 'returns user to profile page if they have previously signed up' do
        sign_in_and_2fa_user
        loa3_sp_session

        visit verify_path
        click_idv_cancel

        expect(current_url).to eq(account_url)
      end
    end
  end

  context 'continuing verification' do
    let(:user) { profile.user }
    let(:otp) { 'abc123' }
    let(:profile) do
      create(
        :profile,
        deactivation_reason: :verification_pending,
        phone_confirmed: phone_confirmed,
        pii: { otp: otp, ssn: '6666', dob: '1920-01-01' }
      )
    end

    context 'having previously selected USPS verification' do
      let(:phone_confirmed) { false }

      it 'prompts for OTP at sign in' do
        saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)

        visit saml_authn_request

        sign_in_live_with_2fa(user)

        expect(current_path).to eq verify_account_path

        fill_in 'Secret code', with: otp
        click_button t('forms.verify_profile.submit')

        expect(current_url).to eq saml_authn_request
      end
    end

    context 'having previously cancelled phone verification' do
      let(:phone_confirmed) { true }

      it 'prompts for OTP at sign in, then continues' do
        saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)

        visit saml_authn_request

        sign_in_live_with_2fa(user)

        enter_correct_otp_code_for_user(user)

        expect(current_url).to eq saml_authn_request
      end
    end
  end

  context 'visiting sign_up_completed path before proofing' do
    it 'redirects to verify_path' do
      sign_in_and_2fa_user

      visit loa3_authnrequest
      visit sign_up_completed_path

      expect(current_path).to eq verify_path
    end
  end
end
