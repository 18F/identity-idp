module Idv
  class LinkSentController < ApplicationController
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_upload_step_complete
    before_action :confirm_document_capture_needed

    def show
      analytics.idv_doc_auth_link_sent_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('link_sent', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
      analytics.idv_doc_auth_link_sent_submitted(analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('link_sent', :update, true)

      return render_document_capture_cancelled if document_capture_session&.cancelled_at
      return render_step_incomplete_error unless take_photo_with_phone_successful?

      # The doc capture flow will have fetched the results already. We need
      # to fetch them again here to add the PII to this session
      handle_document_verification_success(document_capture_session_result)

      redirect_to idv_ssn_url
    end

    def extra_view_variables
      { phone: idv_session[:phone_for_mobile_flow] }
    end

    private

    def confirm_upload_step_complete
      return if flow_session['Idv::Steps::UploadStep']

      redirect_to idv_doc_auth_url
    end

    def confirm_document_capture_needed
      return if flow_session['redo_document_capture']

      pii = flow_session['pii_from_doc'] # hash with indifferent access
      return if pii.blank? && !idv_session.verify_info_step_complete?

      redirect_to idv_ssn_url
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'link_sent',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    def handle_document_verification_success(get_results_response)
      save_proofing_components
      extract_pii_from_doc(get_results_response, store_in_session: true)
      mark_upload_step_complete
      flow_session[:flow_path] = @flow.flow_path
    end

    def render_document_capture_cancelled
      mark_upload_step_incomplete
      redirect_to idv_doc_auth_url # was idv_url, why?
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

    def mark_upload_step_complete
      flow_session['Idv::Steps::UploadStep'] = true
    end

    def mark_upload_step_incomplete
      flow_session['Idv::Steps::UploadStep'] = nil
    end

    def successful_response
      FormResponse.new(success: true)
    end

    # copied from Flow::Failure module
    def failure(message, extra = nil)
      flow_session[:error_message] = message
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end
  end
end
