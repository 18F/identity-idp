# frozen_string_literal: true

class RecaptchaAnnotator
  attr_reader :assessment_id, :analytics

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
    def annotate(assessment_id:, reason: nil, annotation: nil)
      return if assessment_id.blank?

      if FeatureManagement.recaptcha_enabled?
        submit_annotation(assessment_id:, reason:, annotation:)
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

    def submit_annotation(assessment_id:, reason:, annotation:)
      RecaptchaService.new.annotate_assessment(assessment_id:, reason:, annotation:)
    end
  end
end
