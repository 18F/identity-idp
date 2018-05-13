require 'rails_helper'

feature 'LOA3 Single Sign On', idv_job: true do
  include SamlAuthHelper
  include IdvHelper

  def perform_id_verification_with_usps_without_confirming_code(user)
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
    visit saml_authn_request
    click_link t('links.sign_in')
    fill_in_credentials_and_submit(user.email, user.password)
    click_submit_default
    click_idv_begin
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_address_choose_usps
    click_on t('idv.buttons.mail.send')
    fill_in :user_password, with: user.password
    click_continue
    click_acknowledge_personal_key
    click_link t('idv.buttons.continue_plain')
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
      it 'returns user to personal key page if they sign up via loa3' do
        user = create(:user, phone: '1 (111) 111-1111', personal_key: nil)
        sign_in_with_warden(user)
        loa3_sp_session

        visit idv_path
        click_on t('links.cancel')
        click_on t('idv.buttons.cancel')

        expect(current_path).to eq(manage_personal_key_path)
      end

      it 'returns user to profile page if they have previously signed up' do
        sign_in_and_2fa_user
        loa3_sp_session

        visit idv_path
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

        visit idv_path
        click_idv_cancel

        expect(current_path).to eq(manage_personal_key_path)
      end

      it 'returns user to profile page if they have previously signed up' do
        sign_in_and_2fa_user
        loa3_sp_session

        visit idv_path
        click_idv_cancel

        expect(current_url).to eq(account_url)
      end
    end
  end

  context 'continuing verification' do
    let(:user) { profile.user }
    let(:profile) do
      create(
        :profile,
        deactivation_reason: :verification_pending,
        phone_confirmed: phone_confirmed,
        pii: { ssn: '6666', dob: '1920-01-01' }
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

        expect(current_path).to eq idv_address_path
      end
    end
  end

  context 'visiting sign_up_completed path before proofing' do
    it 'redirects to idv_path' do
      sign_in_and_2fa_user

      visit loa3_authnrequest
      visit sign_up_completed_path

      expect(current_path).to eq idv_path
    end
  end
end
