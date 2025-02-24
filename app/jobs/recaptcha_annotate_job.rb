# frozen_string_literal: true

class RecaptchaAnnotateJob < ApplicationJob
  def perform(assessment:)
    RecaptchaAnnotator.submit_assessment(assessment)
  end
end
