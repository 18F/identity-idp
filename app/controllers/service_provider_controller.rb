class ServiceProviderController < ApplicationController
  protect_from_forgery with: :null_session

  def update
    authorize do
      if !FeatureManagement.use_dashboard_service_providers?
        render json: { status: 'Service providers updater has not been enabled.' }
        return
      end

      ServiceProviderUpdater.new.run(sp_params['service_provider'])

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

  def sp_params
    return {} unless request.headers['Content-Type'] == 'gzip/json'

    body = request.body.read

    return {} unless body.present?

    JSON.parse(Zlib.gunzip(body))
  end
end
