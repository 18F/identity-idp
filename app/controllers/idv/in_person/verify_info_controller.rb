module Idv
  module InPerson
    class VerifyInfoController < ApplicationController
      include IdvSession
      include StepIndicatorConcern

      before_action :renders_404_if_flag_not_set
      before_action :confirm_two_factor_authenticated
      before_action :confirm_ssn_step_complete
      before_action :confirm_profile_not_already_confirmed

      def show
        @in_person_proofing = true
        @which_verify_controller = idv_in_person_verify_info_path
        @step_indicator_steps = step_indicator_steps

        increment_step_counts
        analytics.idv_doc_auth_verify_visited(**analytics_arguments)
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('verify', :view, true) # specify in_person?

        render 'idv/verify_info/show'
      end

      def update
        return if idv_session.verify_info_step_document_capture_session_uuid
        analytics.idv_doc_auth_verify_submitted(**analytics_arguments)
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('verify', :update, true)
  
        pii[:uuid_prefix] = ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id
  
        ssn_throttle.increment!
        if ssn_throttle.throttled?
          analytics.throttler_rate_limit_triggered(
            throttle_type: :proof_ssn,
            step_name: 'verify_info',
          )
          redirect_to idv_session_errors_ssn_failure_url
          return
        end
  
        if resolution_throttle.throttled?
          redirect_to throttled_url
          return
        end
  
        document_capture_session = DocumentCaptureSession.create(
          user_id: current_user.id,
          issuer: sp_session[:issuer],
        )
        document_capture_session.requested_at = Time.zone.now
  
        idv_session.verify_info_step_document_capture_session_uuid = document_capture_session.uuid
        idv_session.vendor_phone_confirmation = false
        idv_session.user_phone_confirmation = false
  
        Idv::Agent.new(pii).proof_resolution(
          document_capture_session,
          should_proof_state_id: should_use_aamva?(pii),
          trace_id: amzn_trace_id,
          user_id: current_user.id,
          threatmetrix_session_id: flow_session[:threatmetrix_session_id],
          request_ip: request.remote_ip,
        )
  
        redirect_to idv_in_person_verify_info_url
      end

      private

      def renders_404_if_flag_not_set
        unless IdentityConfig.store.doc_auth_in_person_verify_info_controller_enabled
          render_not_found
        end
      end

      ##### Move to VerifyInfoConcern

      # copied from address_controller
      def confirm_ssn_step_complete
        return if pii.present? && pii[:ssn].present?
        redirect_to idv_doc_auth_url
      end

      def confirm_profile_not_already_confirmed
        return unless idv_session.profile_confirmation == true
        redirect_to idv_review_url
      end

      def pii
        @pii = flow_session[:pii_from_user] if flow_session
      end

      def current_flow_step_counts
        user_session['idv/doc_auth_flow_step_counts'] ||= {}
        user_session['idv/doc_auth_flow_step_counts'].default = 0
        user_session['idv/doc_auth_flow_step_counts']
      end

      def increment_step_counts
        current_flow_step_counts['verify'] += 1
      end

      # copied from doc_auth_controller
      def flow_session
        user_session['idv/doc_auth']
      end

      def flow_path
        flow_session[:flow_path]
      end

      def irs_reproofing?
        effective_user&.decorate&.reproof_for_irs?(
          service_provider: current_sp,
        ).present?
      end

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'verify',
          step_count: current_flow_step_counts['verify'],
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }.merge(**acuant_sdk_ab_test_analytics_args)
      end

      # Copied from capture_doc_flow.rb
      # and from doc_auth_flow.rb
      def acuant_sdk_ab_test_analytics_args
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
    end
  end
end
