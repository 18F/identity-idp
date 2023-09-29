module Idv
  class PhoneQuestionController < ApplicationController
    include ActionView::Helpers::DateHelper
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_verify_info_step_needed
    before_action :confirm_agreement_step_complete
    before_action :confirm_hybrid_handoff_needed, only: :show

    def show
      # analytics.idv_doc_auth_smart_phone_visited(**analytics_arguments)

      @title = t('doc_auth.headings.phone_question')
    end

    def confirm_agreement_step_complete
      return if idv_session.idv_consent_given

      redirect_to idv_agreement_url
    end

    def confirm_hybrid_handoff_needed
      if idv_session.skip_hybrid_handoff?
        redirect_to idv_hybrid_handoff_url
      end

      if !FeatureManagement.idv_allow_hybrid_flow?
        redirect_to idv_hybrid_handoff_url
      end

      if idv_session.flow_path.present?
        redirect_to idv_hybrid_handoff_url
      end
    end
  end
end
