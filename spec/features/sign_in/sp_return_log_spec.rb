require 'rails_helper'

RSpec.feature 'SP return logs' do
  include SamlAuthHelper

  it 'updates user id after user authenticates so we can track any user back to issuer', :email do
    user = create(:user, :with_phone)
    visit_idp_from_sp_with_ial1(:oidc)
    fill_in_credentials_and_submit(user.email, user.password)
    click_button t('forms.buttons.submit.default')
    fill_in 'code', with: user.reload.direct_otp
    click_button t('forms.buttons.submit.default')
    click_agree_and_continue

    expect(SpReturnLog.count).to eq(1)
    expect(SpReturnLog.first.user_id).to eq(user.id)
  end

  context 'when user visits several SAML and OIDC SPs multiple times in the same session' do
    it 'always logs the correct SP in SP Return logs' do
      user = create(:user, :with_phone)

      visit_saml_authn_request_url
      sign_in_via_branded_page(user)
      click_submit_default
      click_agree_and_continue
      click_submit_default_twice

      expect(SpReturnLog.count).to eq(1)
      expect(SpReturnLog.last.issuer).to eq 'http://localhost:3000'

      visit_idp_from_sp_with_ial1(:oidc)
      click_agree_and_continue

      expect(SpReturnLog.count).to eq(2)
      expect(SpReturnLog.last.issuer).to eq 'urn:gov:gsa:openidconnect:sp:server_ial1'

      visit_saml_authn_request_url

      expect(SpReturnLog.count).to eq(3)
      expect(SpReturnLog.last.issuer).to eq 'http://localhost:3000'
    end
  end
end
