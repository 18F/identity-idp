module Idv
  class SsnController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern
    include Steps::ThreatMetrixStepHelper
    include ThreatMetrixConcern

    before_action :confirm_not_rate_limited_after_doc_auth
    before_action :confirm_verify_info_step_needed
    before_action :confirm_document_capture_complete
    before_action :confirm_repeat_ssn, only: :show
    before_action :override_csp_for_threat_metrix

    def show
      @step_indicator_steps = step_indicator_steps
      @ssn_form = Idv::SsnFormatForm.new(current_user, idv_session.ssn)

      analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments) if @ssn_form.updating_ssn?
      analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('ssn', :view, true)

      render 'idv/shared/ssn', locals: threatmetrix_view_variables
    end

    def update
      @ssn_form = Idv::SsnFormatForm.new(current_user, idv_session.ssn)
      form_response = @ssn_form.submit(params.require(:doc_auth).permit(:ssn))

      analytics.idv_doc_auth_ssn_submitted(
        **analytics_arguments.merge(form_response.to_h),
      )
      irs_attempts_api_tracker.idv_ssn_submitted(
        ssn: params[:doc_auth][:ssn],
      )

      if form_response.success?
        idv_session.ssn = params[:doc_auth][:ssn]
        idv_session.invalidate_steps_after_ssn!
        redirect_to next_url
      else
        flash[:error] = form_response.first_error_message
        @step_indicator_steps = step_indicator_steps
        render 'idv/shared/ssn', locals: threatmetrix_view_variables
      end
    end

    private

    def confirm_repeat_ssn
      return if !idv_session.ssn
      return if request.referer == idv_verify_info_url

      redirect_to idv_verify_info_url
    end

    def next_url
      if idv_session.pii_from_doc[:state] == 'PR' && !@ssn_form.updating_ssn?
        idv_address_url
      else
        idv_verify_info_url
      end
    end

    def analytics_arguments
      {
        flow_path: idv_session.flow_path,
        step: 'ssn',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(ab_test_analytics_buckets)
    end
  end
end
