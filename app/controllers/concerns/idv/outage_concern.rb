module Idv
  module OutageConcern
    extend ActiveSupport::Concern

    def check_for_outage
      return if flow_session[:skip_vendor_outage]

      return redirect_for_gpo_only if FeatureManagement.idv_gpo_only?
    end

    def redirect_for_gpo_only
      return redirect_to vendor_outage_url unless FeatureManagement.gpo_verification_enabled?

      redirect_to idv_mail_only_warning_url
    end
  end
end
