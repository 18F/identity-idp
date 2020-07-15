module Test
  class OidcTestController < ApplicationController
    def index
      @oidc_authorize_url = oidc_authorize_url
    end

    private

    def oidc_authorize_url
      openid_connect_authorize_path(
        client_id: 'urn:gov:gsa:openidconnect:sp:server',
        response_type: 'code',
        acr_values: acr_values,
        scope: scope,
        redirect_uri: test_oidc_url,
        state: SecureRandom.hex,
        prompt: 'select_account',
        nonce: SecureRandom.hex,
      )
    end

    def acr_values
      if params[:ial].to_i == 2
        Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
      else
        Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
      end
    end

    def scope
      if params[:ial].to_i == 2
        'openid email profile'
      else
        'openid email'
      end
    end
  end
end
