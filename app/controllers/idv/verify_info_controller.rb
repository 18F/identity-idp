module Idv
  class VerifyInfoController < ApplicationController
    include IdvSession

    before_action :render_404_if_verify_info_controller_disabled
    before_action :confirm_two_factor_authenticated
    before_action :confirm_ssn_step_complete

    def show
      increment_step_counts
      analytics.idv_doc_auth_verify_visited(**analytics_arguments)
    end

    def update
      return if idv_session.idv_verify_info_step_document_capture_session_uuid

      pii[:uuid_prefix] = ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id

      throttle = Throttle.new(
        target: Pii::Fingerprinter.fingerprint(pii[:ssn]),
        throttle_type: :proof_ssn,
      )

      if throttle.throttled_else_increment?
        analytics.throttler_rate_limit_triggered(
          throttle_type: :proof_ssn,
          step_name: 'verify_info',
        )
        redirect_to idv_session_errors_ssn_failure_url
        return
      end

      document_capture_session = DocumentCaptureSession.create(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
      )
      document_capture_session.requested_at = Time.zone.now

      idv_session.idv_verify_info_step_document_capture_session_uuid = document_capture_session.uuid

      Idv::Agent.new(pii).proof_resolution(
        document_capture_session,
        should_proof_state_id: should_use_aamva?(pii),
        trace_id: amzn_trace_id,
        user_id: current_user.id,
        threatmetrix_session_id: flow_session[:threatmetrix_session_id],
        request_ip: request.remote_ip,
      )

      redirect_to idv_verify_info_url
    end

    private

    def render_404_if_verify_info_controller_disabled
      render_not_found unless IdentityConfig.store.doc_auth_verify_info_controller_enabled
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
        analytics_id: 'Doc Auth',
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

    # copied from verify_step
    def pii
      @pii = flow_session[:pii_from_doc] if flow_session
    end

    # copied from address_controller
    def confirm_ssn_step_complete
      return if pii.present? && pii[:ssn].present?
      redirect_to idv_doc_auth_url
    end

    def current_flow_step_counts
      user_session['idv/doc_auth_flow_step_counts'] ||= {}
      user_session['idv/doc_auth_flow_step_counts'].default = 0
      user_session['idv/doc_auth_flow_step_counts']
    end

    def increment_step_counts
      current_flow_step_counts['verify'] += 1
    end

    # copied from verify_base_step
    def should_use_aamva?(pii)
      aamva_state?(pii) && !aamva_disallowed_for_service_provider?
    end

    def aamva_state?(pii)
      IdentityConfig.store.aamva_supported_jurisdictions.include?(
        pii['state_id_jurisdiction'],
      )
    end

    def aamva_disallowed_for_service_provider?
      return false if sp_session.nil?
      banlist = IdentityConfig.store.aamva_sp_banlist_issuers
      banlist.include?(sp_session[:issuer])
    end

  end
end
