module Users
  class SpHandoffBouncedController < Devise::SessionsController
    def bounced
      issuer = sp_session[:issuer]
      @sp_name = I18n.t('instructions.sp_handoff_bounced_with_no_sp')
      return if issuer.blank?
      service_provider = ServiceProvider.from_issuer(issuer)
      @sp_name = service_provider.friendly_name
      @sp_link = service_provider.return_to_sp_url
    end
  end
end
