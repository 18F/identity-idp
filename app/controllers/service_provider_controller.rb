class ServiceProviderController < ApplicationController
  protect_from_forgery with: :null_session

  def update
    authorize do
      ServiceProviderUpdater.new.run if FeatureManagement.use_dashboard_service_providers?

      render json: { status: 'If the feature is enabled, service providers have been updated.' }
    end
  end

  def update_one
    authorize do
      ServiceProviderUpdater.new.run_for_one(params[:id]) if FeatureManagement.use_dashboard_service_providers?

      render json: { status: 'If the feature is enabled, service providers have been updated.' }
    end
  end

  private

  def authorize
    if authorization_token_valid?
      yield
    else
      head :unauthorized
    end
  end

  def authorization_token_valid?
    ActiveSupport::SecurityUtils.secure_compare(
      authorization_token,
      IdentityConfig.store.dashboard_api_token,
    )
  end

  def authorization_token
    request.headers['X-LOGIN-DASHBOARD-TOKEN']
  end
end
