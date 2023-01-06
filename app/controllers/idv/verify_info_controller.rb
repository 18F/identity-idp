module Idv
  class VerifyInfoController < ApplicationController
    before_action :render_404_if_verify_info_controller_disabled
    before_action :confirm_two_factor_authenticated
    before_action :confirm_ssn_step_complete

    def analytics_visited_event
      :idv_doc_auth_verify_visited
    end

    def show
      increment_step_counts
      analytics.public_send(
        analytics_visited_event, **analytics_arguments
      )

      render :show, locals: { pii: pii }
    end

    private

    def render_404_if_verify_info_controller_disabled
      render_not_found unless IdentityConfig.store.doc_auth_verify_info_controller_enabled
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'verify',
        step_count: current_flow_step_counts['verify'],
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing,
      }.merge(**extra_analytics_properties)
    end

    # copied from doc_auth_controller
    def flow_session
      user_session['idv/doc_auth']
    end

    def flow_path
      flow_session[:flow_path]
    end

    def irs_reproofing
      effective_user&.decorate&.reproof_for_irs?(
        service_provider: current_sp,
      ).present?
    end

    # Copied from capture_doc_flow.rb
    # and from doc_auth_flow.rb
    def extra_analytics_properties
      capture_session_uuid = flow_session[:document_capture_session_uuid]
      if capture_session_uuid
        {
          acuant_sdk_upgrade_ab_test_bucket:
          AbTests::ACUANT_SDK.bucket(capture_session_uuid),
        }
      else
        {}
      end
    end

    # copied from verify_step
    def pii
      flow_session[:pii_from_doc]
    end

    # copied from address_controller
    def confirm_ssn_step_complete
      return if pii.present?
      redirect_to idv_doc_auth_url
    end

    def current_flow_step_counts
      user_session['doc_auth_flow_step_counts'] ||= {}
      user_session['doc_auth_flow_step_counts'].default = 0
      user_session['doc_auth_flow_step_counts']
    end

    def increment_step_counts
      current_flow_step_counts['verify'] += 1
    end
  end
end
