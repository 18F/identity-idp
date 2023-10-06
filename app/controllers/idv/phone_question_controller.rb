module Idv
  class PhoneQuestionController < ApplicationController
    include ActionView::Helpers::DateHelper
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_verify_info_step_needed
    before_action :confirm_agreement_step_complete
    before_action :confirm_hybrid_handoff_needed, only: :show

    def show
      idv_session.phone_question_visited = true
      analytics.idv_doc_auth_phone_question_visited(**analytics_arguments)

      @title = t('doc_auth.headings.phone_question')
    end

    def phone_with_camera
      analytics.idv_doc_auth_phone_question_submitted(
        **analytics_arguments.
                merge(camera_phone: true),
      )

      redirect_to idv_hybrid_handoff_url
    end

    def phone_without_camera
      idv_session.flow_path = 'standard'
      analytics.idv_doc_auth_phone_question_submitted(
        **analytics_arguments.
                merge(camera_phone: false),
      )

      redirect_to idv_hybrid_handoff_url
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
