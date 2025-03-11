# frozen_string_literal: true

class RecaptchaAnnotateJob < ApplicationJob
  def perform(assessment_id:)
    assessment = RecaptchaAssessment.find(id: assessment_id)
    if assessment.present?
      RecaptchaAnnotator.submit_assessment(assessment)
    end
  end
end
