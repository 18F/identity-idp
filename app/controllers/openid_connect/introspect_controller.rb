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
  # The agency's call is server to server, and the service provider's comes from the browser
  # under the CORS rule configured for this path.
  class IntrospectController < ApplicationController
    include DelegatedEndpointConcern

    def create
      form = OpenidConnectIntrospectForm.new(form_params)
      result = form.submit

      analytics.openid_connect_introspect(**result.to_h.except(:integration_errors))
      log_integration_errors(result)

      challenge = form.www_authenticate
      response.headers['WWW-Authenticate'] = challenge if challenge
      render json: form.response, status: form.http_status
    end

    private

    def endpoint_params
      params.permit(
        :client_assertion, :client_assertion_type, :client_id, :token, :token_type_hint
      )
    end
  end
end
