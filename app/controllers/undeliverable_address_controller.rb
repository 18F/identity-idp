class UndeliverableAddressController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    authorize do
      UndeliverableAddressNotifier.call

      render plain: 'ok'
    end
  end

  private

  def authorize
    # Check for empty to make sure that the token is configured
    if authorization_token && authorization_token == Figaro.env.usps_download_token
      yield
    else
      head :unauthorized
    end
  end

  def authorization_token
    request.headers['X-API-AUTH-TOKEN']
  end
end
