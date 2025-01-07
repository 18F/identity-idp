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

  class << self
    def annotate(assessment_id:, reason: nil, annotation: nil)
      return if assessment_id.blank?

      if FeatureManagement.recaptcha_enterprise?
        submit_annotation(assessment_id:, reason:, annotation:)
      end

      { assessment_id:, reason:, annotation: }
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

  private

  BASE_ENDPOINT = 'https://recaptchaenterprise.googleapis.com/v1'
end
