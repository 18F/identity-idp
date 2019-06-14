require 'rails_helper'

feature 'LOA3 Single Sign On' do
  include SamlAuthHelper
  include IdvHelper
  include DocAuthHelper

  def perform_id_verification_with_usps_without_confirming_code(user)
    saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
    visit saml_authn_request
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_continue
    click_on t('idv.form.activate_by_mail')
    click_on t('idv.buttons.mail.send')
    fill_in :user_password, with: user.password
    click_continue
    click_acknowledge_personal_key
    click_link t('idv.buttons.continue_plain')
  end

  def mock_usps_mail_bounced
    allow_any_instance_of(UserDecorator).to receive(:usps_mail_bounced?).and_return(true)
  end

  def update_mailing_address
    click_on t('idv.buttons.mail.resend')
    fill_in :user_password, with: user.password
    click_continue
    click_acknowledge_personal_key
    click_link t('idv.buttons.continue_plain')
  end

  def sign_out_user
    first(:link, t('links.sign_out')).click
  end

  context 'First time registration' do
    let(:email) { 'test@test.com' }
    before do
      @saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
    end

    it 'shows user the start page with accordion' do
      saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
      sp_content = [
        'Test SP',
        t('headings.create_account_with_sp.sp_text'),
      ].join(' ')

      visit saml_authn_request

      expect(current_path).to match new_user_session_path
      expect(page).to have_content(sp_content)
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

  context 'continuing verification' do
    let(:user) { profile.user }
    let(:profile) do
      create(
        :profile,
        deactivation_reason: :verification_pending,
        pii: { ssn: '6666', dob: '1920-01-01' },
      )
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
          expect(current_path).to eq(idv_usps_path)

          click_button(t('idv.buttons.mail.resend'))

          expect(user.events.usps_mail_sent.size).to eq 2
          expect(current_path).to eq(idv_come_back_later_path)
        end

        it 'after signing out' do
          user = create(:user, :signed_up)

          perform_id_verification_with_usps_without_confirming_code(user)
          sign_out_user

          sign_in_live_with_2fa(user)

          expect(current_path).to eq verify_account_path

          click_link(t('idv.messages.usps.resend'))

          expect(user.events.account_verified.size).to be(0)
          expect(current_path).to eq(idv_usps_path)

          click_button(t('idv.buttons.mail.resend'))

          expect(current_path).to eq(idv_come_back_later_path)
        end
      end

      context 'provides an option to update address if undeliverable' do
        it 'allows the user to update the address' do
          user = create(:user, :signed_up)

          perform_id_verification_with_usps_without_confirming_code(user)

          expect(current_path).to eq account_path

          mock_usps_mail_bounced
          visit account_path
          click_link(t('account.index.verification.update_address'))

          expect(current_path).to eq idv_usps_path

          fill_out_address_form_fail
          click_on t('idv.buttons.mail.resend')

          fill_out_address_form_ok
          update_mailing_address
        end

        it 'throttles resolution' do
          user = create(:user, :signed_up)

          perform_id_verification_with_usps_without_confirming_code(user)

          expect(current_path).to eq account_path

          mock_usps_mail_bounced
          visit account_path
          click_link(t('account.index.verification.update_address'))

          expect(current_path).to eq idv_usps_path
          fill_out_address_form_resolution_fail
          click_on t('idv.buttons.mail.resend')
          expect(current_path).to eq idv_usps_path
          expect(page).to have_content(t('idv.failure.sessions.heading'))

          fill_out_address_form_resolution_fail
          click_on t('idv.buttons.mail.resend')
          expect(current_path).to eq idv_usps_path
          expect(page).to have_content(strip_tags(t('idv.failure.sessions.fail')))
        end
      end
    end

    context 'returning to verify after canceling during the same session' do
      it 'allows the user to verify' do
        user = create(:user, :signed_up)
        saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)

        visit saml_authn_request
        sign_in_live_with_2fa(user)
        fill_out_idv_jurisdiction_ok
        click_idv_continue
        fill_out_idv_form_ok
        click_idv_continue
        click_on t('links.cancel')
        click_on t('forms.buttons.cancel')
        visit saml_authn_request
        fill_out_idv_jurisdiction_ok
        click_idv_continue
        fill_out_idv_form_ok
        click_idv_continue

        expect(current_path).to eq idv_session_success_path
      end
    end
  end

  context 'visiting sign_up_completed path before proofing' do
    it 'redirects to idv_path' do
      sign_in_and_2fa_user

      visit loa3_authnrequest
      visit sign_up_completed_path

      expect(current_path).to eq idv_jurisdiction_path
    end
  end
end
