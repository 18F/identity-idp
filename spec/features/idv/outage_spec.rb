require 'rails_helper'

def sign_in_with_idv_required(user:, sms_or_totp: :sms)
  visit_idp_from_sp_with_ial2(:oidc)
  sign_in_user(user)
  case sms_or_totp
  when :sms
    fill_in_code_with_last_phone_otp
  when :totp
    fill_in_code_with_last_totp(user)
  end
  click_submit_default
end

RSpec.feature 'IdV Outage Spec' do
  include PersonalKeyHelper
  include IdvStepHelper

  let(:user) { create(:user, :fully_registered) }
  let(:new_password) { 'some really awesome new password' }
  let(:pii) { { ssn: '666-66-1234', dob: '1920-01-01', first_name: 'alice' } }

  let(:vendor_status_acuant) { :operational }
  let(:vendor_status_lexisnexis_instant_verify) { :operational }
  let(:vendor_status_lexisnexis_phone_finder) { :operational }
  let(:vendor_status_lexisnexis_trueid) { :operational }
  let(:vendor_status_sms) { :operational }
  let(:vendor_status_voice) { :operational }

  let(:enable_usps_verification) { true }
  let(:feature_idv_force_gpo_verification_enabled) { false }
  let(:feature_idv_hybrid_flow_enabled) { true }

  let(:vendors) do
    %w[
      acuant
      lexisnexis_instant_verify
      lexisnexis_phone_finder
      lexisnexis_trueid
      sms
      voice
    ]
  end

  let(:config_flags) do
    %w[
      enable_usps_verification
      feature_idv_force_gpo_verification_enabled
      feature_idv_hybrid_flow_enabled
    ]
  end

  before do
    # Wire up various let()s to configuration keys
    vendors.each do |service|
      vendor_status_key = "vendor_status_#{service}".to_sym
      allow(IdentityConfig.store).to receive(vendor_status_key).
        and_return(send(vendor_status_key))
    end

    config_flags.each do |key|
      allow(IdentityConfig.store).to receive(key).
        and_return(send(key))
    end

    # Configuration / vendor status changes can effect Rails routing tables.
    # Force routes to be reloaded when we've modified configuration.
    Rails.application.reload_routes!
  end

  after do
    # Don't leave stale routes sitting around!
    # - Reset all the feature flags that could cause route changes
    # - Reload routes to reset the environment for any specs that run next

    vendors.each do |service|
      vendor_status_key = "vendor_status_#{service}".to_sym
      allow(IdentityConfig.store).to receive(vendor_status_key).and_call_original
    end

    config_flags.each do |key|
      allow(IdentityConfig.store).to receive(key).and_call_original
    end

    # Let e.g. frontend analytics requests to /api/logger settle before we reload routes
    # to avoid flakiness in CI.
    page.server.wait_for_pending_requests if page&.server

    Rails.application.reload_routes!
  end

  context 'vendor_status_lexisnexis_phone_finder set to full_outage' do
    let(:vendor_status_lexisnexis_phone_finder) { :full_outage }

    it 'takes the user through the mail only flow, allowing hybrid', js: true do
      sign_in_with_idv_required(user: user)

      expect(current_path).to eq idv_mail_only_warning_path

      click_idv_continue

      expect(current_path).to eq idv_welcome_path

      complete_welcome_step
      complete_agreement_step

      # Still offer the option for hybrid flow
      expect(current_path).to eq idv_hybrid_handoff_path

      complete_hybrid_handoff_step
      complete_document_capture_step
      complete_ssn_step
      complete_verify_step

      expect(current_path).to eq idv_request_letter_path
    end
  end

  context 'GPO only enabled, but user starts over' do
    let(:feature_idv_force_gpo_verification_enabled) { true }

    it 'shows mail only warning page before idv welcome page', js: true do
      sign_in_with_idv_required(user: user)

      expect(current_path).to eq idv_mail_only_warning_path

      complete_doc_auth_steps_before_document_capture_step
      click_on t('links.cancel')
      click_on t('idv.cancel.actions.start_over')

      expect(current_path).to eq idv_mail_only_warning_path
    end
  end

  context 'force GPO only without phone outages' do
    let(:feature_idv_force_gpo_verification_enabled) { true }

    it 'shows mail only warning page before idv welcome page' do
      sign_in_with_idv_required(user: user)

      expect(current_path).to eq idv_mail_only_warning_path

      click_idv_continue

      expect(current_path).to eq idv_welcome_path
    end
  end

  context 'force GPO only, but GPO not enabled' do
    let(:feature_idv_force_gpo_verification_enabled) { true }
    let(:enable_usps_verification) { false }

    it 'shows mail only warning page before idv welcome page' do
      sign_in_with_idv_required(user: user)

      expect(current_path).to eq vendor_outage_path
    end
  end

  context 'phone outage' do
    let(:user) { user_with_totp_2fa }

    %i[vendor_status_sms vendor_status_voice].each do |flag|
      context "#{flag} set to full_outage" do
        let(flag) { :full_outage }

        it 'shows mail only warning page before idv welcome page' do
          sign_in_with_idv_required(user: user, sms_or_totp: :totp)

          expect(current_path).to eq idv_mail_only_warning_path

          click_idv_continue

          expect(current_path).to eq idv_welcome_path
        end

        it 'returns to the correct page when clicking to exit' do
          sign_in_with_idv_required(user: user, sms_or_totp: :totp)

          click_on t('links.exit_login', app_name: APP_NAME)

          expect(current_url).to eq 'https://example.com/'
        end

        it 'skips the hybrid handoff screen and proceeds to doc capture' do
          sign_in_with_idv_required(user: user, sms_or_totp: :totp)
          click_idv_continue
          click_idv_continue
          complete_agreement_step

          expect(current_path).to eq idv_document_capture_path
        end
      end
    end
  end

  context 'feature_idv_force_gpo_verification_enabled set to true' do
    let(:feature_idv_force_gpo_verification_enabled) { true }
    let(:user) { user_with_2fa }

    it 'shows mail only warning page before idv welcome page' do
      sign_in_with_idv_required(user: user, sms_or_totp: :sms)

      expect(current_path).to eq idv_mail_only_warning_path

      click_idv_continue

      expect(current_path).to eq idv_welcome_path
    end

    it 'still allows the hybrid handoff screen' do
      sign_in_with_idv_required(user: user, sms_or_totp: :sms)
      click_idv_continue
      click_idv_continue
      complete_agreement_step

      expect(current_path).to eq idv_hybrid_handoff_path
    end
  end

  context 'feature_idv_hybrid_flow_enabled set to false' do
    let(:user) { user_with_2fa }
    let(:feature_idv_hybrid_flow_enabled) { false }

    it 'does not show the mail only warning page before idv welcome page' do
      sign_in_with_idv_required(user: user, sms_or_totp: :sms)

      expect(current_path).to eq idv_welcome_path
    end

    it 'does not show the hybrid handoff screen' do
      sign_in_with_idv_required(user: user, sms_or_totp: :sms)
      click_idv_continue
      click_idv_continue
      complete_agreement_step

      expect(current_path).to eq idv_document_capture_path
    end
  end

  %w[acuant lexisnexis_instant_verify lexisnexis_trueid].each do |service|
    context "vendor_status_#{service} set to full_outage", js: true do
      let(:user) { user_with_2fa }
      let("vendor_status_#{service}".to_sym) { :full_outage }

      it 'prevents an existing ial1 user from verifying their identity' do
        sign_in_with_idv_required(user: user, sms_or_totp: :sms)
        expect(page).to have_content(
          strip_tags(t('idv.unavailable.idv_explanation.with_sp_html', sp: 'Test SP')),
        )
      end

      it 'prevents a user who reset their password from reactivating profile with no personal key',
         email: true do
        personal_key_from_pii(user, pii)
        trigger_reset_password_and_click_email_link(user.email)
        reset_password(user, new_password)

        visit new_user_session_path
        signin(user.email, new_password)
        fill_in_code_with_last_phone_otp
        click_submit_default

        click_link t('account.index.reactivation.link')
        click_on t('links.account.reactivate.without_key')
        click_on t('forms.buttons.continue')

        expect(page).to have_content(t('idv.unavailable.idv_explanation.without_sp'))
      end

      it 'prevents a user from creating an account' do
        visit_idp_from_sp_with_ial2(:oidc)
        click_link t('links.create_account')
        expect(page).to have_content(
          strip_tags(
            t(
              'idv.unavailable.idv_explanation.with_sp_html',
              sp: 'Test SP',
            ),
          ),
        )
      end
    end
  end
end
