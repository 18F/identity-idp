# frozen_string_literal: true

module OpenidConnect
  # What the delegated-access endpoints a service provider or an agency API calls directly (token
  # revocation, token introspection) share. The caller is a server, or a browser public client
  # carrying a DPoP proof, so there is no session and no CSRF token; the form authenticates the
  # caller. The endpoints exist only while delegated access is switched on.
  module DelegatedEndpointConcern
    extend ActiveSupport::Concern
    include RenderConditionConcern

    included do
      check_or_render_not_found -> { IdentityConfig.store.token_exchange_enabled }

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration
      skip_before_action :verify_authenticity_token
    end

    def options
      head :ok
    end

    private

    # The form body plus the RFC 9449 proof, which travels in the `DPoP` request header rather
    # than the body. Only the header can supply a proof: the including controller's
    # `endpoint_params` do not permit a `dpop_proof` body field. An empty header reads as no proof.
    def form_params
      endpoint_params.to_h.merge(dpop_proof: request.headers['DPoP'].presence)
    end

    # A failed request from a caller that named itself is also reported as an integration error,
    # which partner support reads to see which service provider sent what.
    def log_integration_errors(result)
      integration_errors = result.to_h[:integration_errors]
      return if result.success? || integration_errors.blank?

      analytics.sp_integration_errors_present(**integration_errors)
    end
  end
end
