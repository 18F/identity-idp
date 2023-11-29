module Idv
  module InPerson
    class VerifyInfoController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include StepIndicatorConcern
      include Steps::ThreatMetrixStepHelper
      include VerifyInfoConcern

      before_action :confirm_not_rate_limited_after_doc_auth, except: [:show]
      before_action :confirm_ssn_step_complete

      def show
        @step_indicator_steps = step_indicator_steps
        @ssn = idv_session.ssn
        @pii = pii

        analytics.idv_doc_auth_verify_visited(**analytics_arguments)
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('verify', :view, true) # specify in_person?

        process_async_state(load_async_state)
      end

      def update
        clear_future_steps!
        idv_session.invalidate_verify_info_step!
        success = shared_update

        if success
          redirect_to idv_in_person_verify_info_url
        end
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :ipp_verify_info,
          controller: self,
          next_steps: [:phone],
          preconditions: ->(idv_session:, user:) do
            idv_session.ssn && idv_session.ipp_document_capture_complete?
          end,
          undo_step: ->(idv_session:, user:) do
            idv_session.resolution_successful = nil
            idv_session.verify_info_step_document_capture_session_uuid = nil
            idv_session.threatmetrix_review_status = nil
            idv_session.applicant = nil
          end,
        )
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
        pii_from_user[:state_id_type] = 'drivers_license' unless invalid_state?
      end

      def invalid_state?
        pii_from_user.blank?
      end

      def prev_url
        idv_in_person_ssn_url
      end

      def pii
        user_session['idv/in_person'][:pii_from_user]
      end

      # override IdvSession concern
      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def analytics_arguments
        {
          flow_path: idv_session.flow_path,
          step: 'verify',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }.merge(ab_test_analytics_buckets).
          merge(**extra_analytics_properties)
      end

      def confirm_ssn_step_complete
        return if pii.present? && idv_session.ssn.present?
        redirect_to prev_url
      end
    end
  end
end
