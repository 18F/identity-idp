require 'rails_helper'

feature 'IAL2 Single Sign On' do
  include SamlAuthHelper
  include IdvStepHelper
  include DocAuthHelper

  def saml_ial2_request_url
    saml_authn_request_url(
      overrides: {
        issuer: 'saml_sp_ial2',
        authn_context: [
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
          "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
          "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
        ],
      },
    )
  end

  def perform_id_verification_with_gpo_without_confirming_code(user)
    visit saml_ial2_request_url
    fill_in_credentials_and_submit(user.email, user.password)
    uncheck(t('forms.messages.remember_device'))
    fill_in_code_with_last_phone_otp
    click_submit_default
    complete_all_doc_auth_steps
    click_on t('idv.troubleshooting.options.verify_by_mail')
    click_on t('idv.buttons.mail.send')
    fill_in t('idv.form.password'), with: user.password
    click_continue
    acknowledge_and_confirm_personal_key
    click_link t('idv.buttons.continue_plain')
  end

  def expected_gpo_return_to_sp_url
    URI.join(
      ServiceProvider.find_by(issuer: 'saml_sp_ial2').acs_url,
      '/',
    ).to_s
  end

  def mock_gpo_mail_bounced
    allow_any_instance_of(UserDecorator).to receive(:gpo_mail_bounced?).and_return(true)
  end

  def update_mailing_address
    click_on t('idv.buttons.mail.resend')
    fill_in t('idv.form.password'), with: user.password
    click_continue
    acknowledge_and_confirm_personal_key
    click_link t('idv.buttons.continue_plain')
  end

  def sign_out_user
    first(:link, t('links.sign_out')).click
  end

  context 'First time registration' do
    let(:email) { 'test@test.com' }

    it 'shows user the start page with accordion' do
      sp_content = [
        'Test SP',
        t('headings.create_account_with_sp.sp_text', app_name: APP_NAME),
      ].join(' ')

      visit saml_ial2_request_url

      expect(current_path).to match new_user_session_path
      expect(page).to have_content(sp_content)
    end

    it 'shows user the start page with a link back to the SP' do
      visit saml_authn_request_url

      expect(page).to have_link(
        t('links.back_to_sp', sp: 'Your friendly Government Agency'), href: return_to_sp_cancel_path
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

    context 'having previously selected USPS verification', js: true do
      let(:phone_confirmed) { false }

      context 'provides an option to send another letter' do
        it 'without signing out' do
          user = create(:user, :signed_up)

          perform_id_verification_with_gpo_without_confirming_code(user)

          expect(current_url).to eq expected_gpo_return_to_sp_url

          visit account_path
          click_link(t('account.index.verification.reactivate_button'))

          expect(current_path).to eq idv_gpo_verify_path

          click_link(t('idv.messages.gpo.resend'))

          expect(user.events.account_verified.size).to be(0)
          expect(current_path).to eq(idv_gpo_path)

          click_button(t('idv.buttons.mail.resend'))

          expect(user.events.gpo_mail_sent.size).to eq 2
          expect(current_path).to eq(idv_come_back_later_path)
        end

        it 'after signing out' do
          user = create(:user, :signed_up)

          perform_id_verification_with_gpo_without_confirming_code(user)
          visit account_path
          sign_out_user

          sign_in_live_with_2fa(user)

          expect(current_path).to eq idv_gpo_verify_path

          click_link(t('idv.messages.gpo.resend'))

          expect(user.events.account_verified.size).to be(0)
          expect(current_path).to eq(idv_gpo_path)

          click_button(t('idv.buttons.mail.resend'))

          expect(current_path).to eq(idv_come_back_later_path)
        end
      end

      context 'provides an option to update address if undeliverable' do
        it 'allows the user to update the address' do
          user = create(:user, :signed_up)

          perform_id_verification_with_gpo_without_confirming_code(user)

          expect(current_url).to eq expected_gpo_return_to_sp_url

          visit account_path

          mock_gpo_mail_bounced
          visit account_path
          click_link(t('account.index.verification.update_address'))

          expect(current_path).to eq idv_gpo_path

          fill_out_address_form_fail
          click_on t('idv.buttons.mail.resend')

          fill_out_address_form_ok
          update_mailing_address
        end

        it 'throttles resolution' do
          user = create(:user, :signed_up)

          perform_id_verification_with_gpo_without_confirming_code(user)

          expect(current_url).to eq expected_gpo_return_to_sp_url

          visit account_path

          mock_gpo_mail_bounced
          visit account_path
          click_link(t('account.index.verification.update_address'))

          expect(current_path).to eq idv_gpo_path
          fill_out_address_form_resolution_fail
          click_on t('idv.buttons.mail.resend')
          expect(current_path).to eq idv_gpo_path
          expect(page).to have_content(t('idv.failure.sessions.heading'))

          fill_out_address_form_resolution_fail
          click_on t('idv.buttons.mail.resend')
          expect(current_path).to eq idv_gpo_path
          expect(page).to have_content(strip_tags(t('idv.failure.sessions.heading')))
        end
      end
    end
  end

  context 'visiting sign_up_completed path before proofing' do
    it 'redirects to idv_path' do
      sign_in_and_2fa_user

      visit_saml_authn_request_url(
        overrides: {
          issuer: sp1_issuer,
          authn_context: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        },
      )
      visit sign_up_completed_path

      expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)
    end
  end
end
