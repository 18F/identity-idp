module Idv
  class PhoneQuestionController < ApplicationController
    include ActionView::Helpers::DateHelper
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_verify_info_step_needed
    before_action :confirm_agreement_step_complete
    before_action :confirm_hybrid_handoff_needed, only: :show

    def show
      @title = t('doc_auth.headings.phone_question')
    end

    def confirm_agreement_step_complete
      return if idv_session.idv_consent_given

      redirect_to idv_agreement_url
    end
  end
end
