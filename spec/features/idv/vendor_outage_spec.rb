require 'rails_helper'

feature 'vendor_outage_spec' do
  include PersonalKeyHelper
  include IdvStepHelper

  let(:user) { create(:user, :signed_up) }
  let(:new_password) { 'some really awesome new password' }
  let(:pii) { { ssn: '666-66-1234', dob: '1920-01-01', first_name: 'alice' } }

  after(:all) do
    # Reload routes now that config changes made in various contexts have been torn down
    Rails.application.reload_routes!
  end

  %w[acuant lexisnexis_instant_verify lexisnexis_trueid].each do |service|
    context "full outage on #{service}" do
      before do
        allow(IdentityConfig.store).to receive("vendor_status_#{service}".to_sym).
          and_return(:full_outage)

        # Force route reload to pick up route changes implied by above config change
        Rails.application.reload_routes!
      end

      it 'prevents an existing ial1 user from verifying their identity' do
        visit_idp_from_sp_with_ial2(:oidc)
        sign_in_user(user_with_2fa)
        fill_in_code_with_last_phone_otp
        click_submit_default
        expect(page).to have_http_status(503)
        expect(page).to have_content(
          t('idv.unavailable.idv_explanation.with_sp', sp: 'Test SP'),
        )
      end

      it 'prevents a user who reset their password from reactivating profile with no personal key',
         email: true, js: true, allow_browser_log: true do
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

        expect(page).to have_content(t('idv.unavailable.idv_explanation.with_sp', sp: 'Test SP'))
      end
    end
  end
end
