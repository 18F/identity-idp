module Users
  class ServiceProviderInactiveController < ApplicationController
    include FullyAuthenticatable

    def index
      analytics.track_event(Analytics::SP_INACTIVE_VISIT)
      @sp_name = I18n.t('service_providers.errors.generic_sp_name')
      @sp_link = I18n.t('service_providers.errors.generic_sp_link')

      issuer = sp_session[:issuer]
      if issuer.present?
        service_provider = ServiceProvider.from_issuer(issuer)
        @sp_name = service_provider.friendly_name || @sp_name
        @sp_link = service_provider.return_to_sp_url || @sp_link
      end
    end

    def show
      delete_branded_experience
      session[:sp] = {}
      redirect_to root_url
    end
  end
end
