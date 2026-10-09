# frozen_string_literal: true

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

    # The access token arrives under the Bearer scheme, or under the DPoP scheme with a proof in
    # the `DPoP` header when it is bound to the client's key (RFC 9449 §7.1); the proof must name
    # this method and URL.
    def authenticate_identity_via_bearer_token
      verifier = AccessTokenVerifier.new(
        request.env['HTTP_AUTHORIZATION'],
        dpop_proof: request.headers['DPoP'].presence,
        http_method: request.request_method,
        http_url: api_openid_connect_userinfo_url,
      )
      result, identity = verifier.submit
      attributes = result.to_h
      analytics.openid_connect_bearer_token(**attributes.except(:integration_errors))

      if result.success?
        @current_identity = identity
      else
        analytics.sp_integration_errors_present(**attributes[:integration_errors])
        challenge = verifier.www_authenticate
        response.headers['WWW-Authenticate'] = challenge if challenge
        render json: { error: verifier.errors[:access_token].join(' ') },
               status: :unauthorized
      end
    end
  end
end
