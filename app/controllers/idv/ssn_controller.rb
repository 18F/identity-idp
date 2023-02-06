module Idv
  class SsnController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include VerifyInfoConcern

    before_action :render_404_if_ssn_controller_disabled
    before_action :confirm_two_factor_authenticated
    before_action :confirm_pii_from_doc

    def show
      increment_step_counts
      analytics.idv_doc_auth_ssn_visited(**analytics_arguments)
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
  end
end
