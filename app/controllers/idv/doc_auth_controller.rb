module Idv
  class DocAuthController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :redirect_if_mail_bounced
    before_action :redirect_if_pending_profile

    include IdvSession # remove if we retire the non docauth LOA3 flow
    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :idv_doc_auth_step_url,
      final_url: :idv_review_url,
      flow: Idv::Flows::DocAuthFlow,
      analytics_id: Analytics::DOC_AUTH,
    }.freeze

    def redirect_if_mail_bounced
      redirect_to idv_usps_url if current_user.decorate.usps_mail_bounced?
    end

    def redirect_if_pending_profile
      redirect_to verify_account_url if current_user.decorate.pending_profile_requires_verification?
    end
  end
end
