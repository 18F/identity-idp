require 'rails_helper'

describe 'Strong IAL2' do
  include IdvHelper
  include OidcAuthHelper
  include DocAuthHelper

  context 'with a liveness required SP and a current verified profile with no liveness' do
    before do
      ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:sp:server').update!(
        liveness_checking_required: true,
      )
    end
    it 'upgrades user to IAL3' do
      user ||= create(:profile, :active, :verified,
                      pii: { first_name: 'John', ssn: '111223333' }).user
      visit_idp_from_sp_with_ial2(:oidc)
      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue_optional
      expect(page.current_path).to eq(idv_doc_auth_welcome_step)
    end
  end
end
