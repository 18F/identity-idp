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

      track_analytics(**analytics_attributes.except(:integration_errors))

      if !result.success? && analytics_attributes[:integration_errors].present?
        analytics.sp_integration_errors_present(
          **analytics_attributes[:integration_errors],
        )
      end

      render json: response, status: @token_form.http_status
    end

    def options
      head :ok
    end

    def token_form
      if brokered_token_exchange?
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

    def track_analytics(analytics_attributes)
      if brokered_token_exchange?
        analytics.openid_connect_brokered_exchange_token(**analytics_attributes)
      else
        analytics.openid_connect_token(**analytics_attributes)
      end
    end

    def brokered_token_exchange?
      params[:grant_type] == TokenExchange::Constants::GRANT_TYPE
    end
  end
end
