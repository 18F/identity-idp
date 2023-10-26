module Idv
  class PhoneQuestionController < ApplicationController
    include ActionView::Helpers::DateHelper
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_verify_info_step_needed
    before_action :confirm_agreement_step_complete
    before_action :confirm_hybrid_handoff_needed, only: :show

    def show
      analytics.idv_doc_auth_phone_question_visited(**analytics_arguments)

      @title = t('doc_auth.headings.phone_question')
    end

    def phone_with_camera
      idv_session.phone_with_camera = true
      analytics.idv_doc_auth_phone_question_submitted(**analytics_arguments)

      redirect_to idv_hybrid_handoff_url
    end

    def phone_without_camera
      idv_session.flow_path = 'standard'
      idv_session.phone_with_camera = false
      analytics.idv_doc_auth_phone_question_submitted(**analytics_arguments)

      redirect_to idv_document_capture_url
    end

    private

    def confirm_agreement_step_complete
      return if idv_session.idv_consent_given

      redirect_to idv_agreement_url
    end

    def analytics_arguments
      {
        step: 'phone_question',
        analytics_id: 'Doc Auth',
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
        irs_reproofing: irs_reproofing?,
      }.merge(ab_test_analytics_buckets)
    end
  end
end
