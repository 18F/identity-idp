# frozen_string_literal: true

module OpenidConnect
  class TokenController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      @token_form = token_form

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

    def token_form
      if params[:grant_type] == TokenExchange::Constants::GRANT_TYPE
        OpenidConnectTokenExchangeForm.new(token_params)
      else
        OpenidConnectTokenForm.new(token_params)
      end
    end

    def token_params
      params.permit(
        :audience,
        :client_assertion,
        :client_assertion_type,
        :client_id,
        :code,
        :code_verifier,
        :grant_type,
        :requested_token_type,
        :resource,
        :scope,
        :subject_token,
        :subject_token_type,
      )
    end
  end
end
