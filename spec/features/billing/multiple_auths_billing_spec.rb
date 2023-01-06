require 'rails_helper'

feature 'Billing for multiple authentications' do
  include SamlAuthHelper

  context 'signing in at ial2 sp then ial1 sp' do
    before do
      allow(IdentityConfig.store).to receive(:saml_internal_post).and_return(false)
    end
    it 'properly tracks both billing events' do
      pii = { phone: '+12025555555', ssn: '111111111' }
      user = create(:profile, :active, :verified, pii: pii).user
      visit_idp_from_saml_ial2_sp_forceauthn(user)
      visit_idp_from_oidc_ial1
      visit_idp_from_saml_ial2_sp_forceauthn(user, false)

      ial2_sp_return_logs = SpReturnLog.where(user_id: user.id, service_provider: 'saml_sp_ial2')
      expect(ial2_sp_return_logs.count).to eq(2)
      expect(ial2_sp_return_logs.all? { |l| l.ial == 2 })

      ial1_sp_return_logs = SpReturnLog.where(user_id: user.id, service_provider: 'urn:gov:gsa:openidconnect:sp:server')
      expect(ial1_sp_return_logs.count).to eq(1)
      expect(ial1_sp_return_logs.first.ial).to eq(1)
    end
  end

  def visit_idp_from_saml_ial2_sp_forceauthn(user, first_visit = true)
    visit_saml_authn_request_url(
      overrides: {
        issuer: 'saml_sp_ial2',
        force_authn: true,
        authn_context: [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF],
      }
    )
    sign_in_live_with_2fa(user)
    click_agree_and_continue if first_visit
    click_submit_default
  end

  def visit_idp_from_oidc_ial1
    visit_idp_from_sp_with_ial1(:oidc)
    click_agree_and_continue
  end
end
