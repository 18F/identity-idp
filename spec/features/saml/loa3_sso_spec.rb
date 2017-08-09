require 'rails_helper'

feature 'LOA3 Single Sign On', idv_job: true do
  include SamlAuthHelper
  include IdvHelper

  def perform_id_verification_without_activation(user)
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
    visit saml_authn_request
    click_link t('links.sign_in')
    fill_in_credentials_and_submit(user.email, user.password)
    click_submit_default
    click_idv_begin
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue
  end

  def perform_id_verification_with_usps_without_confirming_code(user)
    perform_id_verification_without_activation(user)
    click_idv_address_choose_usps
    click_on t('idv.buttons.mail.send')
    fill_in :user_password, with: user.password
    click_submit_default
    click_acknowledge_personal_key
    click_link t('idv.buttons.return_to_account')
  end

  def cancel_verification
    click_on t('links.cancel')
    click_on t('idv.buttons.cancel')
  end

  def sign_out_user
    first(:link, t('links.sign_out')).click
    click_submit_default
  end

  context 'First time registration' do
    let(:email) { 'test@test.com' }
    before do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      @saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
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
      let(:warning_qualifier) { t('idv.cancel.warning_qualifier') }
      let(:sp_name) { 'Your friendly Government Agency' }

      it 'does not show the service provider name if not signed up via a service provider' do
        sign_in_and_2fa_user
        loa3_sp_session

        visit verify_path
        click_idv_begin
        click_on t('links.cancel')

        modal = page.find('.modal-warning')
        expect(modal).to have_content(
          t(
            'idv.cancel.warning_point_no_sp',
            warning_qualifier: warning_qualifier,
            sp_name: sp_name
          )
        )
      end

      it 'returns user to personal key page if they sign up via loa3' do
        user = create(:user, phone: '1 (111) 111-1111', personal_key: nil)
        sign_in_with_warden(user)
        loa3_sp_session

        visit verify_path

        click_idv_begin
        cancel_verification

        expect(current_path).to eq(manage_personal_key_path)
      end

      it 'returns user to profile page if they have previously signed up' do
        sign_in_and_2fa_user
        loa3_sp_session

        visit verify_path

        click_idv_begin
        cancel_verification

        expect(current_path).to match(account_path)
      end
    end

    context 'without js' do
      it 'returns user to personal key page if they sign up via loa3' do
        user = create(:user, phone: '1 (111) 111-1111', personal_key: nil)
        sign_in_with_warden(user)
        loa3_sp_session

        visit verify_path

        click_idv_begin
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

    let(:return_to_verify_button) { t('idv.buttons.return_to_verify') }

    context 'having selected phone option' do
      let(:phone_confirmed) { false }

      it 'includes a button that will return the user to the activation option page' do
        user = create(:user, :signed_up)
        perform_id_verification_without_activation(user)
        click_idv_address_choose_phone

        expect(page).to have_link(return_to_verify_button)

        click_link(return_to_verify_button)

        expect(current_path).to eq verify_address_path
      end
    end

    context 'having selected mail option' do
      let(:phone_confirmed) { false }

      it 'includes a button that will return the user to the activation option page' do
        user = create(:user, :signed_up)
        perform_id_verification_without_activation(user)
        click_idv_address_choose_usps

        expect(page).to have_link(return_to_verify_button)

        click_link(return_to_verify_button)

        expect(current_path).to eq verify_address_path
      end
    end

    context 'having previously selected USPS verification' do
      let(:phone_confirmed) { false }

      context 'provides an option to send another letter' do
        it 'without signing out' do
          user = create(:user, :signed_up)

          perform_id_verification_with_usps_without_confirming_code(user)

          expect(current_path).to eq account_path

          click_link(t('account.index.verification.reactivate_button'))

          expect(current_path).to eq verify_account_path

          click_link(t('idv.messages.usps.resend'))

          expect(user.events.account_verified.size).to be(0)
          expect(current_path).to eq(verify_usps_path)

          click_button(t('idv.buttons.mail.resend'))

          expect(current_path).to eq(account_path)
        end

        it 'after signing out' do
          user = create(:user, :signed_up)

          perform_id_verification_with_usps_without_confirming_code(user)
          sign_out_user

          sign_in_live_with_2fa(user)

          expect(current_path).to eq verify_account_path

          click_link(t('idv.messages.usps.resend'))

          expect(user.events.account_verified.size).to be(0)
          expect(current_path).to eq(verify_usps_path)

          click_button(t('idv.buttons.mail.resend'))

          expect(current_path).to eq(account_path)
        end
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
