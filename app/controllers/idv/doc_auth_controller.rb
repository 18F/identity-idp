module Idv
  class DocAuthController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :redirect_if_pending_profile
    before_action :redirect_if_pending_in_person_enrollment
    before_action :extend_timeout_using_meta_refresh_for_select_paths

    include IdvSession
    include Flow::FlowStateMachine
    include Idv::DocumentCaptureConcern
    include Idv::ThreatMetrixConcern

    before_action :redirect_if_flow_completed
    before_action :override_document_capture_step_csp
    before_action :update_if_skipping_upload
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :check_for_outage, only: :show
    # rubocop:enable Rails/LexicallyScopedActionFilter

    before_action :override_csp_for_threat_metrix

    FLOW_STATE_MACHINE_SETTINGS = {
      step_url: :idv_doc_auth_step_url,
      final_url: :idv_review_url,
      flow: Idv::Flows::DocAuthFlow,
      analytics_id: Analytics::DOC_AUTH,
    }.freeze

    def return_to_sp
      redirect_to return_to_sp_failure_to_proof_url(step: next_step, location: params[:location])
    end

    def redirect_if_pending_profile
      return if sp_session[:ial2_strict] &&
                !IdentityConfig.store.gpo_allowed_for_strict_ial2
      redirect_to idv_gpo_verify_url if current_user.decorate.pending_profile_requires_verification?
    end

    def redirect_if_flow_completed
      flow_finish if idv_session.applicant
    end

    def redirect_if_pending_in_person_enrollment
      return if !IdentityConfig.store.in_person_proofing_enabled
      redirect_to idv_in_person_ready_to_verify_url if current_user.pending_in_person_enrollment
    end

    def update_if_skipping_upload
      return if params[:step] != 'upload' || !flow_session || !flow_session[:skip_upload_step]
      track_step_visited
      update
    end

    def extend_timeout_using_meta_refresh_for_select_paths
      return unless request.path == idv_doc_auth_step_path(step: :link_sent) && flow_session
      max_10min_refreshes = IdentityConfig.store.doc_auth_extend_timeout_by_minutes / 10
      return if max_10min_refreshes <= 0
      meta_refresh_count = flow_session[:meta_refresh_count].to_i
      return if meta_refresh_count >= max_10min_refreshes
      do_meta_refresh(meta_refresh_count)
    end

    def do_meta_refresh(meta_refresh_count)
      @meta_refresh = 10 * 60
      flow_session[:meta_refresh_count] = meta_refresh_count + 1
    end

    def flow_session
      user_session['idv/doc_auth']
    end

    def check_for_outage
      if VendorStatus.new.any_ial2_vendor_outage?
        session[:vendor_outage_redirect] = current_step
        session[:vendor_outage_redirect_from_idv] = true
        redirect_to vendor_outage_url
      end
    end
  end
end
