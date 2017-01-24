class ServiceProviderController < ApplicationController
  protect_from_forgery with: :null_session

  def update
    if FeatureManagement.use_dashboard_service_providers?
      ServiceProviderUpdater.new.run
      SecureHeadersWhitelister.new.run
    end

    render json: { status: 'If the feature is enabled, service providers have been updated.' }
  end
end
