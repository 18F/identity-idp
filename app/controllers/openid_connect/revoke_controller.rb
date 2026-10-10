# frozen_string_literal: true

module OpenidConnect
  # RFC 7009 token revocation for delegated access: `POST /api/openid_connect/revoke`. A service
  # provider ends a refresh family, or one delegated access token, before it would have expired.
  #
  # The answer is HTTP 200 with an empty JSON object whenever the caller authenticated, whatever
  # the token turned out to be (RFC 7009 §2.2), so the endpoint cannot be used to probe tokens.
  class RevokeController < ApplicationController
    include DelegatedEndpointConcern

    def create
      form = OpenidConnectRevokeForm.new(form_params)
      result = form.submit

      analytics.openid_connect_revoke(**result.to_h.except(:integration_errors))
      log_integration_errors(result)

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
