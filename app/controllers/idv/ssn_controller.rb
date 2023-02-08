module Idv
  class SsnController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include VerifyInfoConcern
    include Steps::ThreatMetrixStepHelper

    before_action :render_404_if_ssn_controller_disabled
    before_action :confirm_two_factor_authenticated
    before_action :confirm_pii_from_doc

    attr_accessor :error_message

    def show
      increment_step_counts
      analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

      render :show, locals: extra_view_variables
    end

    def update
      error_message = nil
      form_response = form_submit
      unless form_response.success?
        error_message = form_response.first_error_message
        redirect_to :show
      end

      flow_session[:pii_from_doc][:ssn] = params[:ssn]

      @flow.irs_attempts_api_tracker.idv_ssn_submitted(
        ssn: ssn,
      )

      idv_session.delete('applicant')
    end

    def extra_view_variables
      {
        updating_ssn: updating_ssn,
        success_alert_enabled: !updating_ssn,
        error_message: error_message,
        **threatmetrix_view_variables,
      }
    end

    private

    def render_404_if_ssn_controller_disabled
      render_not_found unless IdentityConfig.store.doc_auth_ssn_controller_enabled
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'ssn',
        step_count: current_flow_step_counts['ssn'],
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
      current_flow_step_counts['ssn'] += 1
    end

    def form_submit
      Idv::SsnFormatForm.new(current_user).submit(permit(:ssn))
    end

    def updating_ssn
      flow_session.dig(:pii_from_doc, :ssn).present?
    end
  end
end
