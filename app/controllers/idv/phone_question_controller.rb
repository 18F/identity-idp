module Idv
  class PhoneQuestionController < ApplicationController
    include ActionView::Helpers::DateHelper
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_verify_info_step_needed
    before_action :confirm_step_allowed
    before_action :confirm_hybrid_handoff_needed, only: :show

    def show
      analytics.idv_doc_auth_phone_question_visited(**analytics_arguments)

      @title = t('doc_auth.headings.phone_question')
    end

    def phone_with_camera
      analytics.idv_doc_auth_phone_question_submitted(
        **analytics_arguments.
                merge(phone_with_camera: true),
      )

      redirect_to idv_hybrid_handoff_url
    end

    def phone_without_camera
      idv_session.flow_path = 'standard'
      analytics.idv_doc_auth_phone_question_submitted(
        **analytics_arguments.
                merge(phone_with_camera: false),
      )

      redirect_to idv_document_capture_url
    end

    def self.navigation_step
      Idv::StepInfo.new(
        controller: controller_name,
        next_steps: [:hybrid_handoff, :document_capture],
        preconditions: ->(idv_session:, user:) do
          AbTests::IDV_PHONE_QUESTION.bucket(user.uuid) == :show_phone_question &&
            idv_session.idv_consent_given
        end,
      )
    end

    private

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
