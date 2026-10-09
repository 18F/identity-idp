# frozen_string_literal: true

module OpenidConnect
  class TokenController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    AUTHORIZATION_CODE_GRANT = 'authorization_code'
    TOKEN_EXCHANGE_GRANT = OpenidConnectTokenExchangeForm::GRANT_TYPE
    REFRESH_TOKEN_GRANT = OpenidConnectRefreshTokenForm::GRANT_TYPE

    def create
      @token_form = build_form

      result = @token_form.submit
      response = @token_form.response

      analytics_attributes = result.to_h
      analytics_attributes[:expires_in] = response[:expires_in]

      analytics.public_send(analytics_event, **analytics_attributes.except(:integration_errors))
      log_refresh_token_reuse(analytics_attributes) if analytics_attributes[:reuse_detected]

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
        :grant_type, :refresh_token, :requested_token_type, :scope, :subject_token,
        :subject_token_type, :resource, resource: []
      )
    end

    private

    # One form per grant type. RFC 8693 token exchange and the RFC 6749 §6 refresh grant are
    # served at this endpoint while delegated access is switched on; every other grant type
    # Login.gov does not serve is answered with the RFC 6749 §5.2 `unsupported_grant_type` error.
    def build_form
      case params[:grant_type]
      when AUTHORIZATION_CODE_GRANT
        OpenidConnectTokenForm.new(form_params)
      when TOKEN_EXCHANGE_GRANT
        return OpenidConnectUnsupportedGrantForm.new(form_params) unless token_exchange_enabled?

        OpenidConnectTokenExchangeForm.new(form_params)
      when REFRESH_TOKEN_GRANT
        return OpenidConnectUnsupportedGrantForm.new(form_params) unless token_exchange_enabled?

        OpenidConnectRefreshTokenForm.new(form_params)
      else
        OpenidConnectUnsupportedGrantForm.new(form_params)
      end
    end

    # A spent refresh token presented again is a sign the token was stolen, so it gets its own
    # event, which operations can alert on.
    def log_refresh_token_reuse(analytics_attributes)
      analytics.delegation_refresh_token_reuse(
        service_provider_issuer: analytics_attributes[:service_provider_issuer],
        resource_server_identifier: analytics_attributes[:resource_server_identifier],
        family_id: analytics_attributes[:family_id],
      )
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

    # The delegated-access grants have their own events because they carry different attributes.
    def analytics_event
      return :openid_connect_token unless token_exchange_enabled?

      case params[:grant_type]
      when TOKEN_EXCHANGE_GRANT then :openid_connect_token_exchange
      when REFRESH_TOKEN_GRANT then :openid_connect_token_refresh
      else :openid_connect_token
      end
    end
  end
end
