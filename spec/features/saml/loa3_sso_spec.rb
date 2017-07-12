require 'rails_helper'

feature 'LOA3 Single Sign On' do
  include SamlAuthHelper
  include IdvHelper

  def perform_id_verification_with_usps_without_confirming_code_then_sign_out(user)
    saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
    visit saml_authn_request
    sign_in_live_with_2fa(user)
    click_idv_begin
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue
    click_idv_address_choose_usps
    click_on t('idv.buttons.mail.send')
    fill_in :user_password, with: user.password
    click_submit_default
    click_acknowledge_personal_key
    first(:link, t('links.sign_out')).click
    click_submit_default
  end

  context 'First time registration' do
    let(:email) { 'test@test.com' }
    before do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      @saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
    end

    it 'redirects to original SAML Authn Request after IdV is complete', email: true do
      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

      visit @saml_authn_request

      saml_register_loa3_user(email)

      expect(current_path).to eq verify_path

      click_idv_begin

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
        expect(page).to have_content t('help_text.requested_attributes.full_name')
        expect(page).to have_content t('help_text.requested_attributes.phone')
        expect(page).to have_content t('help_text.requested_attributes.social_security_number')
      end

      click_on I18n.t('forms.buttons.continue')
      expect(current_url).to eq @saml_authn_request

      user_access_key = user.unlock_user_access_key(Features::SessionHelper::VALID_PASSWORD)
      profile_phone = user.active_profile.decrypt_pii(user_access_key).phone

      expect(user.events.account_verified.size).to be(1)
      expect(xmldoc.phone_number.children.children.to_s).to eq(profile_phone)
    end

    it 'allows the user to select verification via USPS letter', email: true do
      visit @saml_authn_request

      saml_register_loa3_user(email)

      click_idv_begin

      fill_out_idv_form_ok
      click_idv_continue
      fill_out_financial_form_ok
      click_idv_continue

      click_idv_address_choose_usps

      click_on t('idv.buttons.mail.send')

      expect(current_path).to eq verify_review_path
      expect(page).to_not have_content t('idv.messages.phone.phone_of_record')

      fill_in :user_password, with: user_password

      expect { click_submit_default }.
        to change { UspsConfirmation.count }.from(0).to(1)

      expect(current_url).to eq verify_confirmations_url
      click_acknowledge_personal_key

      expect(User.find_with_email(email).events.account_verified.size).to be(0)
      expect(current_url).to eq(account_url)
      expect(page).to have_content(t('account.index.verification.reactivate_button'))

      usps_confirmation_entry = UspsConfirmation.last.decrypted_entry
      expect(usps_confirmation_entry.issuer).
        to eq('https://rp1.serviceprovider.com/auth/saml/metadata')
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

    it 'shows user the start page with a link back to the SP' do
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request

      cancel_callback_url = 'http://localhost:3000'

      expect(page).to have_link(
        t('links.back_to_sp', sp: 'Your friendly Government Agency'), href: cancel_callback_url
      )
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

      it 'prompts for confirmation code at sign in' do
        allow(FeatureManagement).to receive(:reveal_usps_code?).and_return(true)

        saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
        visit saml_authn_request
        sign_in_live_with_2fa(user)

        expect(current_path).to eq verify_account_path
        expect(page).to have_content t('idv.messages.usps.resend')

        click_button t('forms.verify_profile.submit')

        expect(user.events.account_verified.size).to be(1)
        expect(current_path).to eq(sign_up_completed_path)

        find('input').click

        expect(current_url).to eq saml_authn_request
      end

      it 'provides an option to send another letter' do
        user = create(:user, :signed_up)

        perform_id_verification_with_usps_without_confirming_code_then_sign_out(user)

        sign_in_live_with_2fa(user)

        expect(current_path).to eq verify_account_path

        click_link(t('idv.messages.usps.resend'))

        expect(user.events.account_verified.size).to be(0)
        expect(current_path).to eq(verify_usps_path)
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

    context 'returning to verify after canceling during the same session' do
      it 'allows the user to verify' do
        user = create(:user, :signed_up)
        saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)

        visit saml_authn_request
        sign_in_live_with_2fa(user)
        click_idv_begin
        fill_out_idv_form_ok
        click_idv_continue
        click_idv_cancel
        visit saml_authn_request
        click_idv_begin
        fill_out_idv_form_ok
        click_idv_continue

        expect(current_path).to eq verify_finance_path
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
