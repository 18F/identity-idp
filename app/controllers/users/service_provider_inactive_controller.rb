module Users
  class ServiceProviderInactiveController < ApplicationController
    include FullyAuthenticatable

    def index
      analytics.sp_inactive_visit

      @sp_name = sp_from_sp_session&.friendly_name ||
                 I18n.t('service_providers.errors.generic_sp_name')

      delete_branded_experience(logout: true)
    end
  end
end
