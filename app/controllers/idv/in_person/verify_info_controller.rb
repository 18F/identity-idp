module Idv
  module InPerson
    class VerifyInfoController < ApplicationController
      include IdvSession
      include StepIndicatorConcern
      include StepUtilitiesConcern
      include VerifyInfoConcern

      before_action :renders_404_if_flag_not_set
      before_action :confirm_two_factor_authenticated
      before_action :confirm_ssn_step_complete
      before_action :confirm_profile_not_already_confirmed

      def show
        @in_person_proofing = true
        @verify_info_submit_path = idv_in_person_verify_info_path
        @step_indicator_steps = step_indicator_steps

        increment_step_counts
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

      def update
        return if idv_session.verify_info_step_document_capture_session_uuid
        analytics.idv_doc_auth_verify_submitted(**analytics_arguments)
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('verify', :update, true)

        pii[:uuid_prefix] = ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id
        pii[:state_id_type] = 'drivers_license' unless pii.blank?
        add_proofing_component

        ssn_throttle.increment!
        if ssn_throttle.throttled?
          idv_failure_log_throttled(:proof_ssn)
          analytics.throttler_rate_limit_triggered(
            throttle_type: :proof_ssn,
            step_name: 'verify_info',
          )
          redirect_to idv_session_errors_ssn_failure_url
          return
        end

        if resolution_throttle.throttled?
          idv_failure_log_throttled(:idv_resolution)
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

      def prev_url
        idv_in_person_url
      end

      def renders_404_if_flag_not_set
        render_not_found unless IdentityConfig.store.in_person_verify_info_controller_enabled
      end

      def add_proofing_component
        ProofingComponent.
          create_or_find_by(user: current_user).
          update(document_check: Idp::Constants::Vendors::USPS)
      end

      # copied from address_controller
      def confirm_ssn_step_complete
        return if pii.present? && pii[:ssn].present?
        redirect_to idv_in_person_url
      end

      def confirm_profile_not_already_confirmed
        # todo: should this instead be like so?
        # return unless idv_session.resolution_successful == true
        return unless idv_session.verify_info_step_complete?
        redirect_to idv_phone_url
      end

      def pii
        @pii = flow_session[:pii_from_user] if flow_session
      end

      def delete_pii
        flow_session.delete(:pii_from_doc)
        flow_session.delete(:pii_from_user)
      end

      def current_flow_step_counts
        user_session['idv/in_person_flow_step_counts'] ||= {}
        user_session['idv/in_person_flow_step_counts'].default = 0
        user_session['idv/in_person_flow_step_counts']
      end

      def increment_step_counts
        current_flow_step_counts['verify'] += 1
      end

      # override StepUtilitiesConcern
      def flow_session
        user_session['idv/in_person']
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

      # copied from verify_base_step. May want reconciliation with phone_step
      def process_async_state(current_async_state)
        if current_async_state.none?
          idv_session.resolution_successful = false
          render 'idv/verify_info/show'
        elsif current_async_state.in_progress?
          render 'shared/wait'
        elsif current_async_state.missing?
          analytics.idv_proofing_resolution_result_missing
          flash.now[:error] = I18n.t('idv.failure.timeout')
          render 'idv/verify_info/show'

          delete_async
          idv_session.resolution_successful = false

          log_idv_verification_submitted_event(
            success: false,
            failure_reason: { idv_verification: [:timeout] },
          )
        elsif current_async_state.done?
          async_state_done(current_async_state)
        end
      end
    end
  end
end
