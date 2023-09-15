module Idv
  module InPerson
    class VerifyInfoController < ApplicationController
      include IdvStepConcern
      include StepIndicatorConcern
      include Steps::ThreatMetrixStepHelper
      include VerifyInfoConcern

      before_action :confirm_ssn_step_complete
      before_action :confirm_verify_info_step_needed
      skip_before_action :confirm_not_rate_limited, only: :show

      def show
        @step_indicator_steps = step_indicator_steps
        @ssn = idv_session.ssn || flow_session[:pii_from_user][:ssn]

        analytics.idv_doc_auth_verify_visited(**analytics_arguments)
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('verify', :view, true) # specify in_person?

        process_async_state(load_async_state)
      end

      def update
        success = shared_update

        if success
          redirect_to idv_in_person_verify_info_url
        end
      end

      private

      def flow_param
        'in_person'
      end

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

      def prev_url
        idv_in_person_ssn_url
      end

      def pii
        @pii = flow_session[:pii_from_user]
      end

      # override IdvSession concern
      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def analytics_arguments
        {
          flow_path: flow_session[:flow_path],
          step: 'verify',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }.merge(ab_test_analytics_buckets).
          merge(**extra_analytics_properties)
      end
    end
  end
end
