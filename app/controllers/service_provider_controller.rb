class ServiceProviderController < ApplicationController
  protect_from_forgery with: :null_session

  def update
    authorize do
      if FeatureManagement.use_dashboard_service_providers?
        ServiceProviderUpdater.new.run
      end

      render json: { status: 'If the feature is enabled, service providers have been updated.' }
    end
  end

  private

  def authorize
    if authorization_token == Figaro.env.dashboard_api_token
      yield
    else
      render nothing: true, status: 401
    end
  end

  def authorization_token
    @authorization_token ||= authorization_header
  end

  def authorization_header
    request.headers['X-LOGIN-DASHBOARD-TOKEN']
  end
end
