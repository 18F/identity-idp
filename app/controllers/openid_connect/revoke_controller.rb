# frozen_string_literal: true

module OpenidConnect
  # RFC 7009 token revocation for delegated access: `POST /api/openid_connect/revoke`. A service
  # provider ends a refresh family, or one delegated access token, before it would have expired.
  # No session and no CSRF token: the caller is a server or a browser public client with a DPoP
  # proof, authenticated by the form. The endpoint exists only while delegated access is on.
  #
  # The answer is HTTP 200 with an empty JSON object whenever the caller authenticated, whatever
  # the token turned out to be (RFC 7009 §2.2), so the endpoint cannot be used to probe tokens.
  class RevokeController < ApplicationController
    include RenderConditionConcern

    check_or_render_not_found -> { IdentityConfig.store.token_exchange_enabled }

    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      form = OpenidConnectRevokeForm.new(form_params)
      result = form.submit

      analytics_attributes = result.to_h
      analytics.openid_connect_revoke(**analytics_attributes.except(:integration_errors))
      if !result.success? && analytics_attributes[:integration_errors].present?
        analytics.sp_integration_errors_present(**analytics_attributes[:integration_errors])
      end

      render json: form.response, status: form.http_status
    end

    def options
      head :ok
    end

    private

    def revoke_params
      params.permit(
        :client_assertion, :client_assertion_type, :client_id, :token, :token_type_hint
      )
    end

    # The form body plus the RFC 9449 proof, which travels in the `DPoP` request header rather
    # than the body. An empty header reads as no proof.
    def form_params
      revoke_params.to_h.merge(dpop_proof: request.headers['DPoP'].presence)
    end
  end
end
