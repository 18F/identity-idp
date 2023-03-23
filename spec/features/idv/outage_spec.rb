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

feature 'IdV Outage Spec' do
  include PersonalKeyHelper
  include IdvStepHelper

  let(:user) { create(:user, :signed_up) }
  let(:new_password) { 'some really awesome new password' }
  let(:pii) { { ssn: '666-66-1234', dob: '1920-01-01', first_name: 'alice' } }

  context 'phone outage', js: true do
    let(:user) { user_with_totp_2fa }

    %i[vendor_status_sms vendor_status_voice].each do |flag|
      context "#{flag} set to full_outage" do
        before do
          allow(IdentityConfig.store).to receive(flag).
            and_return(:full_outage)
        end

        it 'shows mail only warning page before idv welcome page' do
          sign_in_with_idv_required(user: user, sms_or_totp: :totp)

          expect(current_path).to eq idv_mail_only_warning_path

          click_idv_continue

          expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)
        end

        it 'returns to the correct page when clicking to exit', js: true do
          sign_in_with_idv_required(user: user, sms_or_totp: :totp)

          click_on t('links.exit_login', app_name: APP_NAME)

          expect(current_url).to eq 'https://example.com/'
        end

        it 'skips the hybrid handoff screen and proceeds to doc capture' do
          sign_in_with_idv_required(user: user, sms_or_totp: :totp)
          click_idv_continue
          click_idv_continue
          complete_agreement_step

          expect(current_path).to eq idv_doc_auth_step_path(step: :document_capture)
        end
      end
    end
  end

  context 'feature_idv_force_gpo_verification_enabled set to true', js: true do
    let(:user) { user_with_2fa }

    before do
      allow(IdentityConfig.store).to receive(:feature_idv_force_gpo_verification_enabled).
        and_return(true)
    end

    it 'shows mail only warning page before idv welcome page', js: true do
      sign_in_with_idv_required(user: user, sms_or_totp: :sms)

      expect(current_path).to eq idv_mail_only_warning_path

      click_idv_continue

      expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)
    end

    it 'still allows the hybrid handoff screen' do
      sign_in_with_idv_required(user: user, sms_or_totp: :sms)
      click_idv_continue
      click_idv_continue
      complete_agreement_step

      expect(current_path).to eq idv_doc_auth_step_path(step: :upload)
    end
  end

  context 'feature_idv_hybrid_flow_enabled set to false', js: true do
    let(:user) { user_with_2fa }

    before do
      allow(IdentityConfig.store).to receive(:feature_idv_hybrid_flow_enabled).
        and_return(false)
    end

    it 'does not show the mail only warning page before idv welcome page' do
      sign_in_with_idv_required(user: user, sms_or_totp: :sms)

      expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)
    end

    it 'does not show the hybrid handoff screen' do
      sign_in_with_idv_required(user: user, sms_or_totp: :sms)
      click_idv_continue
      click_idv_continue
      complete_agreement_step

      expect(current_path).to eq idv_doc_auth_step_path(step: :document_capture)
    end
  end

  %w[acuant lexisnexis_instant_verify lexisnexis_trueid].each do |service|
    context "vendor_status_#{service} set to full_outage" do
      let(:user) { user_with_2fa }
      before do
        allow(IdentityConfig.store).to receive("vendor_status_#{service}".to_sym).
          and_return(:full_outage)
      end

      it 'prevents an existing ial1 user from verifying their identity' do
        sign_in_with_idv_required(user: user, sms_or_totp: :sms)
        expect(current_path).to eq vendor_outage_path
        expect(page).to have_content(
          t('vendor_outage.blocked.idv.with_sp', service_provider: 'Test SP'),
        )
      end

      it 'prevents a user who reset their password from reactivating profile with no personal key',
         email: true, js: true do
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

        expect(current_path).to eq vendor_outage_path
        expect(page).to have_content(t('vendor_outage.blocked.idv.without_sp'))
      end

      it 'prevents a user from creating an account' do
        visit_idp_from_sp_with_ial2(:oidc)
        click_link t('links.create_account')
        expect(current_path).to eq vendor_outage_path
        expect(page).to have_content(t('vendor_outage.blocked.idv.generic'))
      end
    end
  end
end
