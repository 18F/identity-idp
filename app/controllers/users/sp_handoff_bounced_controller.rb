module Users
  class SpHandoffBouncedController < Devise::SessionsController
    def bounced
      analytics.sp_handoff_bounced_visit
      @sp_name = I18n.t('instructions.sp_handoff_bounced_with_no_sp')
      update_sp_info
    end

    private

    def update_sp_info
      issuer = sp_session[:issuer]
      return if issuer.blank?
      service_provider = ServiceProvider.find_by(issuer: issuer)
      @sp_name = service_provider&.friendly_name || 'Null ServiceProvider'
      @sp_link = service_provider&.return_to_sp_url
    end
  end
end
