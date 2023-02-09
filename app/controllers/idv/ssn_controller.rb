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
      @error_message = nil
      form_response = form_submit

      unless form_response.success?
        @error_message = form_response.first_error_message
        redirect_to idv_ssn_url
      end

      flow_session['pii_from_doc'][:ssn] = params[:doc_auth][:ssn]

      irs_attempts_api_tracker.idv_ssn_submitted(
        ssn: params[:doc_auth][:ssn],
      )

      idv_session.applicant = nil

      redirect_to idv_verify_info_url
    end

    def extra_view_variables
      {
        updating_ssn: updating_ssn,
        success_alert_enabled: !updating_ssn,
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
      Idv::SsnFormatForm.new(current_user).submit(params.require('doc_auth').permit(:ssn))
    end

    def updating_ssn
      flow_session.dig('pii_from_doc', :ssn).present?
    end
  end
end
