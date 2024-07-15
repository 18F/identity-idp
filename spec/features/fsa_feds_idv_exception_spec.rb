require 'rails_helper'

RSpec.feature 'the FSA-specific exception to IdV', allowed_extra_analytics: [:*] do
  include SamlAuthHelper
  include OidcAuthHelper
  include IdvHelper

  shared_examples 'FSA IdV exception' do |protocol|
    before do
      allow(IdentityConfig.store).to receive(:allowed_fsa_feds_idv_exception_providers).
        and_return(['saml_sp_ial2', 'urn:gov:gsa:openidconnect:sp:server'])

      if protocol == :saml
        visit_saml_authn_request_url(
          overrides: {
            issuer: 'saml_sp_ial2',
            authn_context: [
              Saml::Idp::Constants::IAL2_FSA_FEDS_IDV_EXCEPTION_CONTEXT_CLASSREF,
              "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}ssn",
            ],
          },
        )
      elsif protocol == :oidc
        visit openid_connect_authorize_path(
          client_id: 'urn:gov:gsa:openidconnect:sp:server',
          response_type: 'code',
          acr_values: Saml::Idp::Constants::IAL2_FSA_FEDS_IDV_EXCEPTION_CONTEXT_CLASSREF,
          scope: 'openid email profile:name social_security_number',
          redirect_uri: 'http://localhost:7654/auth/result',
          state: SecureRandom.hex,
          prompt: 'login',
          nonce: SecureRandom.hex,
        )
      end
    end

    context 'the user has not proofed' do
      it 'requires the user to complete proofing' do
        user = create(:user, :fully_registered)
        sign_in_live_with_2fa(user)
        click_submit_default if protocol == :saml
        expect(current_path).to eq(idv_welcome_path)
      end
    end

    context 'the user has proofed' do
      it 'redirects to the SP without prompting the user to proof' do
        user = create(:user, :proofed)
        sign_in_live_with_2fa(user)
        click_submit_default if protocol == :saml
        expect(current_path).to eq(sign_up_completed_path)
        click_agree_and_continue

        if protocol == :saml
          click_submit_default
          expect(page).to have_current_path(
            api_saml_finalauthpost_path(path_year: SamlAuthHelper::PATH_YEAR),
          )
        else
          redirect_uri = URI(oidc_redirect_url)
          expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
        end
      end
    end

    context 'the user has an IdV exception case' do
      it 'redirects to the SP without prompting the user to proof' do
        user = create(
          :user,
          :fully_registered,
          email: 'test@test.gov',
          piv_cac_recommended_dismissed_at: Time.zone.now,
        )
        sign_in_live_with_2fa(user)
        click_submit_default if protocol == :saml
        expect(current_path).to eq(sign_up_completed_path)
        click_agree_and_continue

        if protocol == :saml
          click_submit_default
          expect(page).to have_current_path(
            api_saml_finalauthpost_path(path_year: SamlAuthHelper::PATH_YEAR),
          )
        else
          redirect_uri = URI(oidc_redirect_url)
          expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
        end
      end
    end
  end

  it_behaves_like 'FSA IdV exception', :oidc
  it_behaves_like 'FSA IdV exception', :saml
end
