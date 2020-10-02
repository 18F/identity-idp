# Subclass this class to implement a controller that requires
# an authentication token supplied in the X-API-AUTH-TOKEN header.
# The required token value is defined by implementing a
# #config_auth_token method.
class AuthTokenController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authorize

  private

  def authorize
    return if auth_token_valid?
    head :unauthorized
  end

  def auth_token_valid?
    return false if request_auth_token.blank?
    ActiveSupport::SecurityUtils.secure_compare(
      request_auth_token,
      config_auth_token,
    )
  end

  def request_auth_token
    request.headers['X-API-AUTH-TOKEN']
  end

  def config_auth_token
    raise NotImplementedError
  end
end
