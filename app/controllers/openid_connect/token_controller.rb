# frozen_string_literal: true

module OpenidConnect
  class TokenController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      @token_form = OpenidConnectTokenForm.new(form_params)

      result = @token_form.submit
      response = @token_form.response

      analytics_attributes = result.to_h
      analytics_attributes[:expires_in] = response[:expires_in]

      analytics.openid_connect_token(**analytics_attributes.except(:integration_errors))

      if !result.success? && analytics_attributes[:integration_errors].present?
        analytics.sp_integration_errors_present(
          **analytics_attributes[:integration_errors],
        )
      end

      render json: response,
             status: (result.success? ? :ok : :bad_request)
    end

    def options
      head :ok
    end

    def token_params
      params.permit(:client_assertion, :client_assertion_type, :code, :code_verifier, :grant_type)
    end

    private

    # The form body plus the RFC 9449 proof, which travels in the `DPoP` request header rather
    # than the body. Only the header can supply a proof: a `dpop_proof` body field is not
    # permitted above, so it is dropped before the merge. An empty header reads as no proof.
    def form_params
      token_params.to_h.merge(dpop_proof: request.headers['DPoP'].presence)
    end
  end
end
