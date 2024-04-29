# frozen_string_literal: true

class RecaptchaAnnotator
  attr_reader :assessment_id, :analytics

  # See: https://cloud.google.com/recaptcha-enterprise/docs/reference/rest/v1/projects.assessments/annotate#reason
  module AnnotationReasons
    INITIATED_TWO_FACTOR = :INITIATED_TWO_FACTOR
    PASSED_TWO_FACTOR = :PASSED_TWO_FACTOR
  end

  # See: https://cloud.google.com/recaptcha-enterprise/docs/reference/rest/v1/projects.assessments/annotate#annotation
  module Annotations
    LEGITIMATE = :LEGITIMATE
    FRAUDULENT = :FRAUDULENT
  end

  def initialize(assessment_id:, analytics:)
    @assessment_id = assessment_id
    @analytics = analytics
  end

  def annotate(reason: nil, annotation: nil)
    submit_annotation(reason:, annotation:) if !IdentityConfig.store.phone_recaptcha_mock_validator
    log_analytics(reason:, annotation:)
  end

  private

  BASE_ENDPOINT = 'https://recaptchaenterprise.googleapis.com/v1/projects'

  def submit_annotation(reason:, annotation:)
    request_body = { reason:, annotation: }.compact
    faraday.post(annotation_url, request_body) do |request|
      request.options.context = { service_name: 'recaptcha_annotate' }
    end
  end

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.request :json
      conn.response :json
    end
  end

  def annotation_url
    UriService.add_params(
      format(
        '%{base_endpoint}/%{project_id}/assessments/%{assessment_id}:annotate',
        base_endpoint: BASE_ENDPOINT,
        project_id: IdentityConfig.store.recaptcha_enterprise_project_id,
        assessment_id:,
      ),
      key: IdentityConfig.store.recaptcha_enterprise_api_key,
    )
  end

  def log_analytics(reason:, annotation:)
    analytics&.recaptcha_assessment_annotated(assessment_id:, reason:, annotation:)
  end
end
