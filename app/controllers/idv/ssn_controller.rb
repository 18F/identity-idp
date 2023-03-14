module Idv
  class SsnController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include StepUtilitiesConcern
    include Steps::ThreatMetrixStepHelper

    before_action :confirm_two_factor_authenticated
    before_action :confirm_profile_not_already_confirmed
    before_action :confirm_pii_from_doc

    attr_accessor :error_message

    def show
      increment_step_counts

      analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments) if updating_ssn

      analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('ssn', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
      @error_message = nil
      form_response = form_submit

      analytics.idv_doc_auth_ssn_submitted(
        **analytics_arguments.merge(form_response.to_h),
      )
      irs_attempts_api_tracker.idv_ssn_submitted(
        ssn: params[:doc_auth][:ssn],
      )

      if form_response.success?
        flow_session['pii_from_doc'][:ssn] = params[:doc_auth][:ssn]
        idv_session.invalidate_steps_after_ssn!
        redirect_to next_url
      else
        @error_message = form_response.first_error_message
        render :show, locals: extra_view_variables
      end
    end

    def extra_view_variables
      {
        updating_ssn: updating_ssn,
        success_alert_enabled: !updating_ssn,
        **threatmetrix_view_variables,
      }
    end

    private

    def next_url
      if @pii[:state] == 'PR'
        idv_address_url
      else
        idv_verify_info_url
      end
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'ssn',
        step_count: current_flow_step_counts['Idv::Steps::SsnStep'],
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    def current_flow_step_counts
      user_session['idv/doc_auth_flow_step_counts'] ||= {}
      user_session['idv/doc_auth_flow_step_counts'].default = 0
      user_session['idv/doc_auth_flow_step_counts']
    end

    def increment_step_counts
      current_flow_step_counts['Idv::Steps::SsnStep'] += 1
    end

    def form_submit
      Idv::SsnFormatForm.new(current_user).submit(params.require(:doc_auth).permit(:ssn))
    end

    def updating_ssn
      flow_session.dig('pii_from_doc', :ssn).present?
    end
  end
end
