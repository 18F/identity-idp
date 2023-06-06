module Idv
  class DocAuthController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :redirect_if_pending_gpo
    before_action :redirect_if_pending_in_person_enrollment

    include IdvSession
    include Flow::FlowStateMachine
    include Idv::ThreatMetrixConcern
    include FraudReviewConcern
    include Idv::OutageConcern

    before_action :redirect_if_flow_completed
    before_action :handle_fraud
    before_action :update_if_skipping_upload
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :check_for_outage, only: :show
    # rubocop:enable Rails/LexicallyScopedActionFilter

    before_action :override_csp_for_threat_metrix

    FLOW_STATE_MACHINE_SETTINGS = {
      step_url: :idv_doc_auth_step_url,
      final_url: :idv_hybrid_handoff_url,
      flow: Idv::Flows::DocAuthFlow,
      analytics_id: 'Doc Auth',
    }.freeze

    def return_to_sp
      redirect_to return_to_sp_failure_to_proof_url(step: next_step, location: params[:location])
    end

    def redirect_if_pending_gpo
      redirect_to idv_gpo_verify_url if current_user.gpo_verification_pending_profile?
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

    def do_meta_refresh(meta_refresh_count)
      @meta_refresh = 10 * 60
      flow_session[:meta_refresh_count] = meta_refresh_count + 1
    end

    def flow_session
      user_session['idv/doc_auth']
    end
  end
end
