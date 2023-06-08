module Idv
  module InPerson
    class VerifyInfoController < ApplicationController
      include IdvStepConcern
      include StepIndicatorConcern
      include StepUtilitiesConcern
      include Steps::ThreatMetrixStepHelper
      include VerifyInfoConcern
      include OutageConcern

      before_action :renders_404_if_flag_not_set
      before_action :confirm_ssn_step_complete
      before_action :confirm_verify_info_step_needed
      before_action :check_for_outage, only: :show

      def show
        @step_indicator_steps = step_indicator_steps
        @capture_secondary_id_enabled = capture_secondary_id_enabled

        analytics.idv_doc_auth_verify_visited(**analytics_arguments)
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('verify', :view, true) # specify in_person?

        if ssn_throttle.throttled?
          idv_failure_log_throttled(:proof_ssn)
          redirect_to idv_session_errors_ssn_failure_url
          return
        end

        if resolution_throttle.throttled?
          idv_failure_log_throttled(:idv_resolution)
          redirect_to throttled_url
          return
        end

        process_async_state(load_async_state)
      end

      private

      # state_id_type is hard-coded here because it's required for proofing against
      # AAMVA. We're sticking with driver's license because most states don't discern
      # between various ID types and driver's license is the most common one that will
      # be supported. See also LG-3852 and related findings document.
      def set_state_id_type
        pii[:state_id_type] = 'drivers_license' unless invalid_state?
      end

      def invalid_state?
        pii.blank?
      end

      def after_update_url
        idv_in_person_verify_info_url
      end

      def prev_url
        idv_in_person_step_url(step: :ssn)
      end

      def renders_404_if_flag_not_set
        render_not_found unless IdentityConfig.store.in_person_verify_info_controller_enabled
      end

      def pii
        @pii = flow_session[:pii_from_user]
      end

      # override StepUtilitiesConcern
      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'verify',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }.merge(**acuant_sdk_ab_test_analytics_args)
      end
    end
  end
end
