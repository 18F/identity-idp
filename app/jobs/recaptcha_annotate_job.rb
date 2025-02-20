# frozen_string_literal: true

class RecaptchaAnnotateJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :low

  good_job_control_concurrency_with(
    perform_limit: 1,
    key: -> { "#{self.class.name}-#{queue_name}-#{arguments.last[:assessment_id]}" },
  )

  def perform(assessment_id:, reason:, annotation: nil)
    RecaptchaAnnotator.annotate(assessment_id:, reason:, annotation:)
  end
end
