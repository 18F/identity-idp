module Idv
  class LinkSentController < ApplicationController
    include DocumentCaptureConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_hybrid_handoff_complete
    before_action :confirm_document_capture_needed
    before_action :extend_timeout_using_meta_refresh

    def show
      analytics.idv_doc_auth_link_sent_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('link_sent', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
      analytics.idv_doc_auth_link_sent_submitted(**analytics_arguments)

      return render_document_capture_cancelled if document_capture_session&.cancelled_at
      return render_step_incomplete_error unless take_photo_with_phone_successful?

      # The doc capture flow will have fetched the results already. We need
      # to fetch them again here to add the PII to this session
      handle_document_verification_success(document_capture_session_result)

      redirect_to idv_ssn_url
    end

    def extra_view_variables
      { phone: idv_session.phone_for_mobile_flow,
        flow_session: flow_session }
    end

    private

    def confirm_hybrid_handoff_complete
      return if flow_session[:flow_path] == 'hybrid'

      if flow_session[:flow_path] == 'standard'
        redirect_to idv_document_capture_url
      else
        redirect_to idv_hybrid_handoff_url
      end
    end

    def confirm_document_capture_needed
      return if flow_session['redo_document_capture']

      pii = flow_session['pii_from_doc'] # hash with indifferent access
      return if pii.blank? && !idv_session.verify_info_step_complete?

      redirect_to idv_ssn_url
    end

    def analytics_arguments
      {
        step: 'link_sent',
        analytics_id: 'Doc Auth',
        flow_path: 'hybrid',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    def handle_document_verification_success(get_results_response)
      save_proofing_components(current_user)
      extract_pii_from_doc(current_user, get_results_response, store_in_session: true)
      flow_session[:flow_path] = 'hybrid'
    end

    def render_document_capture_cancelled
      redirect_to idv_hybrid_handoff_url
      flow_session[:flow_path] = nil
      failure(I18n.t('errors.doc_auth.document_capture_cancelled'))
    end

    def render_step_incomplete_error
      failure(I18n.t('errors.doc_auth.phone_step_incomplete'))
    end

    def take_photo_with_phone_successful?
      document_capture_session_result.present? && document_capture_session_result.success?
    end

    def document_capture_session_result
      @document_capture_session_result ||= begin
        document_capture_session&.load_result ||
          document_capture_session&.load_doc_auth_async_result
      end
    end

    def extend_timeout_using_meta_refresh
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
  end
end
