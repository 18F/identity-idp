# frozen_string_literal: true

class RecaptchaAnnotator
  # See: https://cloud.google.com/recaptcha-enterprise/docs/reference/rest/v1/projects.assessments/annotate#reason
  module AnnotationReasons
    INITIATED_TWO_FACTOR = 'INITIATED_TWO_FACTOR'
    PASSED_TWO_FACTOR = 'PASSED_TWO_FACTOR'
    FAILED_TWO_FACTOR = 'FAILED_TWO_FACTOR'
  end

  # See: https://cloud.google.com/recaptcha-enterprise/docs/reference/rest/v1/projects.assessments/annotate#annotation
  module Annotations
    LEGITIMATE = 'LEGITIMATE'
    FRAUDULENT = 'FRAUDULENT'
  end

  class << self
    def annotate(assessment_id:, reason: nil, annotation: nil, analytics: nil)
      return if assessment_id.blank?

      if FeatureManagement.recaptcha_enabled?
        submit_annotation_with_analytics(
          assessment_id:,
          reason:,
          annotation:,
          analytics:,
        )
        # Future:
        # assessment = create_or_update_assessment!(assessment_id:, reason:, annotation:)
        # RecaptchaAnnotateJob.perform_later(assessment:)
      end

      { assessment_id:, reason:, annotation: }
    end

    def submit_assessment(assessment)
      submit_annotation(
        assessment_id: assessment.id,
        annotation: assessment.annotation_before_type_cast,
        reason: assessment.annotation_reason_before_type_cast,
      )
    end

    private

    def create_or_update_assessment!(assessment_id:, reason:, annotation:)
      assessment = RecaptchaAssessment.find_or_initialize_by(id: assessment_id)
      assessment.update(annotation_reason: reason, annotation:)
      assessment
    end

    def submit_annotation_with_analytics(assessment_id:, reason:, annotation:, analytics:)
      started_at = Time.zone.now
      success = false
      error = nil

      begin
        submit_annotation(assessment_id:, reason:, annotation:)
        success = true
      rescue StandardError => error
        raise
      ensure
        analytics&.recaptcha_annotation_result_received(
          reason:,
          annotation:,
          success:,
          exception_class: error&.class&.name,
          duration_ms: TimeService.duration_ms(start: started_at, finish: Time.zone.now),
        )
      end
    end

    def submit_annotation(assessment_id:, reason:, annotation:)
      RecaptchaService.new.annotate_assessment(assessment_id:, reason:, annotation:)
    end
  end
end
