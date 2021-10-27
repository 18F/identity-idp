require 'rails_helper'

feature 'vendor_outage_spec' do
  include IdvStepHelper

  %w[acuant lexisnexis_instant_verify lexisnexis_trueid].each do |service|
    context "full outage on #{service}" do
      before do
        allow(IdentityConfig.store).to receive("vendor_status_#{service}".to_sym).
          and_return('full_outage')
      end

      it 'prevents an existing ial1 user from verifying their identity' do
        visit_idp_from_sp_with_ial2(:oidc)
        sign_in_user(user_with_2fa)
        fill_in_code_with_last_phone_otp
        click_submit_default
        expect(current_path).to eq vendor_outage_path
        expect(page).to have_content(t('vendor_outage.doc_auth.full'))
      end

      it 'prevents a user from creating an account' do
        visit_idp_from_sp_with_ial2(:oidc)
        click_link t('links.create_account')
        expect(current_path).to eq vendor_outage_path
        expect(page).to have_content(t('vendor_outage.doc_auth.full'))
      end
    end
  end
end
