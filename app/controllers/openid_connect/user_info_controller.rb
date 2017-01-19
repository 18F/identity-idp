module OpenidConnect
  class UserInfoController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_identity_via_bearer_token

    attr_reader :current_identity

    def show
      render json: OpenidConnectUserInfoPresenter.new(current_identity).user_info
    end

    private

    def authenticate_identity_via_bearer_token
      verifier = IdTokenVerifier.new(request.env['HTTP_AUTHORIZATION'])
      response = verifier.submit
      analytics.track_event(Analytics::OPENID_CONNECT_BEARER_TOKEN, response.to_h)

      if response.success?
        @current_identity = verifier.identity
      else
        render json: { error: verifier.errors[:id_token].join(' ') },
               status: :unauthorized
      end
    end
  end
end
