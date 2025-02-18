# frozen_string_literal: true

class RecaptchaAnnotateJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  BASE_ENDPOINT = 'https://recaptchaenterprise.googleapis.com/v1'

  queue_as :low

  good_job_control_concurrency_with(
    perform_limit: 1,
    key: -> { "#{self.class.name}-#{queue_name}-#{arguments.last[:assessment_id]}" },
  )

  def perform(assessment_id:, reason: nil, annotation: nil)
    submit_annotation(assessment_id:, reason:, annotation:)
  end

  private

  def submit_annotation(assessment_id:, reason:, annotation:)
    request_body = { annotation:, reasons: reason && [reason] }.compact
    faraday.post(annotation_url(assessment_id:), request_body) do |request|
      request.options.context = { service_name: 'recaptcha_annotate' }
    end
  rescue Faraday::Error => error
    NewRelic::Agent.notice_error(error)
  end

  def faraday
    Faraday.new do |conn|
      conn.options.timeout = IdentityConfig.store.recaptcha_request_timeout_in_seconds

      conn.request :instrumentation, name: 'request_log.faraday'
      conn.request :json
      conn.response :json
    end
  end

  def annotation_url(assessment_id:)
    UriService.add_params(
      format(
        '%{base_endpoint}/%{assessment_id}:annotate',
        base_endpoint: BASE_ENDPOINT,
        project_id: IdentityConfig.store.recaptcha_enterprise_project_id,
        assessment_id:,
      ),
      key: IdentityConfig.store.recaptcha_enterprise_api_key,
    )
  end
end
