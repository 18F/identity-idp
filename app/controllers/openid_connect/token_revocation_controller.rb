# frozen_string_literal: true

module OpenidConnect
  class TokenRevocationController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      form = OpenidConnectTokenRevocationForm.new(
        params.permit(:client_id, :token, :token_type_hint),
      )
      result = form.submit

      analytics.openid_connect_token_revocation(**result.to_h)

      render json: form.response, status: form.http_status
    end
  end
end
