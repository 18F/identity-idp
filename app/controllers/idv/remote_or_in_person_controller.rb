module Idv
  class RemoteOrInPersonController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_welcome_step_complete
    # before_action :confirm_agreement_needed

    def show
      # analytics.idv_doc_auth_agreement_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'remote_or_in_person', :view,
        true
      )
    end

    def update
      if params[:type] == 'remote'
        redirect_to idv_hybrid_handoff_url
      else
        redirect_to_in_person
      end

      # analytics.idv_doc_auth_agreement_submitted(
      #   **analytics_arguments.merge(result.to_h),
      # )
    end

    private

    def redirect_to_in_person
      # todo: is this necessary?
      idv_session.flow_path = 'standard'
      redirect_to idv_opt_in_ipp_url
    end

    def analytics_arguments
      {
        step: 'agreement',
        analytics_id: 'Doc Auth',
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
        irs_reproofing: irs_reproofing?,
      }.merge(ab_test_analytics_buckets)
    end

    def confirm_welcome_step_complete
      return if idv_session.welcome_visited

      redirect_to idv_welcome_url
    end
    #
    # def confirm_agreement_needed
    #   return unless idv_session.idv_consent_given
    #
    #   redirect_to idv_hybrid_handoff_url
    # end
  end
end
