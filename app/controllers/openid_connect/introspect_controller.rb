# frozen_string_literal: true

module OpenidConnect
  # RFC 7662 token introspection for delegated tokens.
  #
  # Two kinds of caller are served. An agency API (resource server) authenticates with a
  # `private_key_jwt` client assertion and, for a token issued for it, learns everything the
  # token stands for: who the person is at that agency, which service provider is acting, what
  # access was approved, and the identity attributes the agency is entitled to. The public-client
  # service provider that holds a token may ask about its own token, identified by `client_id`
  # and proving possession of the key the token is bound to with a DPoP proof over the token; it
  # learns the token's status and what its own sign-in already told it, nothing of the agency's.
  # Everyone else is told only that the token is not active.
  #
  # No session and no CSRF token: the agency's call is server to server, and the service
  # provider's comes from the browser under the CORS rule configured for this path.
  class IntrospectController < ApplicationController
    include RenderConditionConcern

    check_or_render_not_found -> { IdentityConfig.store.token_exchange_enabled }

    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      form = OpenidConnectIntrospectForm.new(form_params)
      result = form.submit

      analytics_attributes = result.to_h
      analytics.openid_connect_introspect(**analytics_attributes.except(:integration_errors))
      if !result.success? && analytics_attributes[:integration_errors].present?
        analytics.sp_integration_errors_present(**analytics_attributes[:integration_errors])
      end

      challenge = form.www_authenticate
      response.headers['WWW-Authenticate'] = challenge if challenge
      render json: form.response, status: form.http_status
    end

    def options
      head :ok
    end

    private

    def introspect_params
      params.permit(
        :client_assertion, :client_assertion_type, :client_id, :token, :token_type_hint
      )
    end

    # The form body plus the RFC 9449 proof, which travels in the `DPoP` request header rather
    # than the body; only the header can supply it. An empty header reads as no proof.
    def form_params
      introspect_params.to_h.merge(dpop_proof: request.headers['DPoP'].presence)
    end
  end
end
