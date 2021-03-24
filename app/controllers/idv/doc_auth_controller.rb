module Idv
  class DocAuthController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :redirect_if_mail_bounced
    before_action :redirect_if_pending_profile
    before_action :extend_timeout_using_meta_refresh_for_select_paths

    include IdvSession # remove if we retire the non docauth LOA3 flow
    include Flow::FlowStateMachine
    include Idv::DocumentCaptureConcern

    before_action :override_document_capture_step_csp
    before_action :update_if_skipping_upload

    FSM_SETTINGS = {
      step_url: :idv_doc_auth_step_url,
      final_url: :idv_review_url,
      flow: Idv::Flows::DocAuthFlow,
      analytics_id: Analytics::DOC_AUTH,
    }.freeze

    def redirect_if_mail_bounced
      redirect_to idv_gpo_url if current_user.decorate.gpo_mail_bounced?
    end

    def redirect_if_pending_profile
      redirect_to verify_account_url if current_user.decorate.pending_profile_requires_verification?
    end

    def update_if_skipping_upload
      return if params[:step] != 'upload' || !flow_session || !flow_session[:skip_upload_step]
      track_step_visited
      update
    end

    def extend_timeout_using_meta_refresh_for_select_paths
      return unless request.path == idv_doc_auth_step_path(step: :link_sent) && flow_session
      max_10min_refreshes = AppConfig.env.doc_auth_extend_timeout_by_minutes / 10
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
  end
end
