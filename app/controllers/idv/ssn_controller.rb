module Idv
  class SsnController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern
    include Steps::ThreatMetrixStepHelper
    include ThreatMetrixConcern

    before_action :confirm_not_rate_limited_after_doc_auth
    before_action :confirm_step_allowed
    before_action :override_csp_for_threat_metrix

    attr_reader :ssn_presenter

    # Keep this code in sync with Idv::InPerson::SsnController

    def show
      @ssn_presenter = Idv::SsnPresenter.new(
        sp_name: decorated_sp_session.sp_name,
        ssn_form: Idv::SsnFormatForm.new(idv_session.ssn),
        step_indicator_steps: step_indicator_steps,
      )

      if ssn_presenter.updating_ssn?
        analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments)
      end
      analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('ssn', :view, true)

      render 'idv/shared/ssn', locals: threatmetrix_view_variables(ssn_presenter.updating_ssn?)
    end

    def update
      clear_future_steps!
      ssn_form = Idv::SsnFormatForm.new(idv_session.ssn)
      form_response = ssn_form.submit(params.require(:doc_auth).permit(:ssn))
      @ssn_presenter = Idv::SsnPresenter.new(
        sp_name: decorated_sp_session.sp_name,
        ssn_form: ssn_form,
        step_indicator_steps: step_indicator_steps,
      )
      analytics.idv_doc_auth_ssn_submitted(
        **analytics_arguments.merge(form_response.to_h),
      )
      irs_attempts_api_tracker.idv_ssn_submitted(
        ssn: params[:doc_auth][:ssn],
      )

      if form_response.success?
        idv_session.ssn = params[:doc_auth][:ssn]
        redirect_to next_url
      else
        flash[:error] = form_response.first_error_message
        render 'idv/shared/ssn', locals: threatmetrix_view_variables(ssn_presenter.updating_ssn?)
      end
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :ssn,
        controller: self,
        next_steps: [:verify_info],
        preconditions: ->(idv_session:, user:) { idv_session.remote_document_capture_complete? },
        undo_step: ->(idv_session:, user:) do
          idv_session.ssn = nil
          idv_session.threatmetrix_session_id = nil
        end,
      )
    end

    private

    def next_url
      if idv_session.pii_from_doc[:state] == 'PR' && !ssn_presenter.updating_ssn?
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
