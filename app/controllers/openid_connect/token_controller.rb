module OpenidConnect
  class TokenController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      @token_form = OpenidConnectTokenForm.new(params)

      result = @token_form.submit
      analytics.track_event(Analytics::OPENID_CONNECT_TOKEN, result)

      render json: @token_form.response,
             status: (result[:success] ? :ok : :bad_request)
    end
  end
end
