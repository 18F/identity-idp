module OpenidConnect
  class UserInfoController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token
    before_action :authenticate_identity_via_bearer_token

    attr_reader :current_identity

    def show
      render json: OpenidConnectUserInfoPresenter.new(current_identity).user_info
    end

    private

    def authenticate_identity_via_bearer_token
      verifier = AccessTokenVerifier.new(request.env['HTTP_AUTHORIZATION'])
      response = verifier.submit
      analytics.openid_connect_bearer_token(**response.to_h)

      if response.success?
        @current_identity = verifier.identity
      else
        render json: { error: verifier.errors[:access_token].join(' ') },
               status: :unauthorized
      end
    end
  end
end
