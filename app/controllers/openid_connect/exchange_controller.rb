# frozen_string_literal: true

module OpenidConnect
  # RFC 8693 token exchange: a service provider trades its own access token (the subject token)
  # for a token bound to one of the user's approved applications. The request is validated and
  # minted by OpenidConnectTokenExchangeForm; this controller only maps it to a JSON response.
  class ExchangeController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      form = OpenidConnectTokenExchangeForm.new(exchange_params, request: request)
      result = form.submit

      analytics.openid_connect_token_exchange(**result.to_h)

      render json: form.response, status: form.http_status
    end

    def options
      head :ok
    end

    private

    def exchange_params
      params.permit(
        :grant_type,
        :subject_token,
        :subject_token_type,
        :audience,
        :requested_token_type,
        :scope,
      )
    end
  end
end
