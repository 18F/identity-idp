# frozen_string_literal: true

module OpenidConnect
  # Browser-callable RFC 8693 token exchange. Lets an allowlisted broker SP
  # trade its access token for a token bound to another SP for the same
  # already-proofed user, without a client secret. The broker may only mint for
  # a user who granted the broker the token-exchange consent during proofing,
  # and only for targets on the broker's signed manifest allowlist.
  class ExchangeController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      form = OpenidConnectTokenExchangeForm.new(exchange_params)
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
