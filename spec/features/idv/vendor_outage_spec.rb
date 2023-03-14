require 'rails_helper'

feature 'vendor_outage_spec' do
  include PersonalKeyHelper
  include IdvStepHelper

  let(:user) { create(:user, :signed_up) }
  let(:new_password) { 'some really awesome new password' }
  let(:pii) { { ssn: '666-66-1234', dob: '1920-01-01', first_name: 'alice' } }

  context "phone outage", js: true do
    let(:user) { user_with_totp_2fa }
    before do
      allow(IdentityConfig.store).to receive(:vendor_status_sms).
        and_return(:full_outage)
      allow(IdentityConfig.store).to receive(:vendor_status_phone).
        and_return(:full_outage)
    end

    it 'shows vendor outage page before idv welcome page' do
      visit_idp_from_sp_with_ial2(:oidc)
      sign_in_user(user)
      fill_in_code_with_last_totp(user)
      click_submit_default
      
      expect(current_path).to eq idv_vendor_outage_path

      click_idv_continue

      expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)
    end

    it 'skips the hybrid handoff screen and proceeds to doc capture' do
      visit_idp_from_sp_with_ial2(:oidc)
      sign_in_user(user)
      fill_in_code_with_last_totp(user)
      click_submit_default
      click_idv_continue
      click_idv_continue
      complete_agreement_step

      expect(current_path).to eq idv_doc_auth_step_path(step: :document_capture)
    end
  end

  %w[acuant lexisnexis_instant_verify lexisnexis_trueid].each do |service|
    context "full outage on #{service}" do
      before do
        allow(IdentityConfig.store).to receive("vendor_status_#{service}".to_sym).
          and_return(:full_outage)
      end

      it 'prevents an existing ial1 user from verifying their identity' do
        visit_idp_from_sp_with_ial2(:oidc)
        sign_in_user(user_with_2fa)
        fill_in_code_with_last_phone_otp
        click_submit_default
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
