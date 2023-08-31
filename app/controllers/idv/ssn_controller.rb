module Idv
  class SsnController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern
    include Steps::ThreatMetrixStepHelper
    include ThreatMetrixConcern

    before_action :confirm_verify_info_step_needed
    before_action :confirm_document_capture_complete
    before_action :confirm_repeat_ssn, only: :show
    before_action :override_csp_for_threat_metrix_no_fsm

    attr_accessor :error_message

    def show
      @ssn_form = Idv::SsnFormatForm.new(current_user, idv_session.ssn, flow_session)

      analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments) if @ssn_form.updating_ssn?
      analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('ssn', :view, true)

      render :show, locals: threatmetrix_view_variables
    end

    def update
      @error_message = nil

      @ssn_form = Idv::SsnFormatForm.new(current_user, idv_session.ssn, flow_session)
      form_response = @ssn_form.submit(params.require(:doc_auth).permit(:ssn))

      analytics.idv_doc_auth_ssn_submitted(
        **analytics_arguments.merge(form_response.to_h),
      )
      irs_attempts_api_tracker.idv_ssn_submitted(
        ssn: params[:doc_auth][:ssn],
      )

      if form_response.success?
        flow_session[:pii_from_doc][:ssn] = params[:doc_auth][:ssn]
        idv_session.ssn = params[:doc_auth][:ssn]
        idv_session.invalidate_steps_after_ssn!
        redirect_to next_url
      else
        @error_message = form_response.first_error_message
        render :show, locals: threatmetrix_view_variables
      end
    end

    private

    def confirm_repeat_ssn
      return if !idv_session.ssn && !pii_from_doc[:ssn]
      return if request.referer == idv_verify_info_url

      redirect_to idv_verify_info_url
    end

    def next_url
      if pii_from_doc[:state] == 'PR' && !updating_ssn?
        idv_address_url
      else
        idv_verify_info_url
      end
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'ssn',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(ab_test_analytics_buckets)
    end

    def updating_ssn?
      @ssn_form.updating_ssn?
    end
  end
end
