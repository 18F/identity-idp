module Users
  class ServiceProviderInactiveController < ApplicationController
    include FullyAuthenticatable

    def index
      analytics.track_event(Analytics::SP_INACTIVE_VISIT)
      @sp_name = I18n.t('service_providers.errors.generic_sp_name')

      issuer = sp_session[:issuer]
      if issuer.present?
        service_provider = ServiceProvider.from_issuer(issuer)
        @sp_name = service_provider.friendly_name || @sp_name
      end

      delete_branded_experience
      session[:sp] = {}
    end
  end
end
