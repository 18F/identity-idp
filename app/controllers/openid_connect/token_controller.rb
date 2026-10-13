# frozen_string_literal: true

module OpenidConnect
  class TokenController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    AUTHORIZATION_CODE_GRANT = 'authorization_code'
    TOKEN_EXCHANGE_GRANT = OpenidConnectTokenExchangeForm::GRANT_TYPE

    def create
      @token_form = build_form

      result = @token_form.submit
      response = @token_form.response

      analytics_attributes = result.to_h
      analytics_attributes[:expires_in] = response[:expires_in]

      analytics.public_send(analytics_event, **analytics_attributes.except(:integration_errors))

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
      params.permit(
        :client_assertion, :client_assertion_type, :client_id, :code, :code_verifier,
        :grant_type, :requested_token_type, :subject_token, :subject_token_type,
        :resource, resource: []
      )
    end

    private

    # One form per grant type. RFC 8693 token exchange is served at this endpoint (RFC 8693 §2.1)
    # while delegated access is switched on; every other grant type Login.gov does not serve is
    # answered with the RFC 6749 §5.2 `unsupported_grant_type` error.
    def build_form
      case params[:grant_type]
      when AUTHORIZATION_CODE_GRANT
        OpenidConnectTokenForm.new(form_params)
      when TOKEN_EXCHANGE_GRANT
        return OpenidConnectUnsupportedGrantForm.new(form_params) unless token_exchange_enabled?

        OpenidConnectTokenExchangeForm.new(form_params)
      else
        OpenidConnectUnsupportedGrantForm.new(form_params)
      end
    end

    # The form body plus the RFC 9449 proof, which travels in the `DPoP` request header rather
    # than the body. Only the header can supply a proof: a `dpop_proof` body field is not
    # permitted above, so it is dropped before the merge. An empty header reads as no proof.
    def form_params
      token_params.to_h.merge(dpop_proof: request.headers['DPoP'].presence)
    end

    def token_exchange_enabled?
      IdentityConfig.store.token_exchange_enabled
    end

    # The exchange has its own event because it carries different attributes.
    def analytics_event
      if params[:grant_type] == TOKEN_EXCHANGE_GRANT && token_exchange_enabled?
        :openid_connect_token_exchange
      else
        :openid_connect_token
      end
    end
  end
end
