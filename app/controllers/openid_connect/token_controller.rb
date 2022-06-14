module OpenidConnect
  class TokenController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      @token_form = OpenidConnectTokenForm.new(token_params)

      result = @token_form.submit
      analytics.openid_connect_token(**result.to_h)

      render json: @token_form.response,
             status: (result.success? ? :ok : :bad_request)
    end

    def options
      head :ok
    end

    def token_params
      params.permit(:client_assertion, :client_assertion_type, :code, :code_verifier, :grant_type)
    end
  end
end
